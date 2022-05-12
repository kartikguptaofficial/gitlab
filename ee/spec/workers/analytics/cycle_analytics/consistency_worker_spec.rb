# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::ConsistencyWorker do
  let(:worker) { described_class.new }

  context 'when the vsa_incremental_worker feature flag is off' do
    before do
      stub_feature_flags(vsa_consistency_worker: false)
    end

    it 'does nothing' do
      expect(Analytics::CycleAnalytics::Aggregation).not_to receive(:load_batch)

      worker.perform
    end
  end

  context 'when the vsa_consistency_worker feature flag is on' do
    before do
      stub_feature_flags(vsa_consistency_worker: true)
    end

    context 'when no pending aggregation records present' do
      before do
        expect(Analytics::CycleAnalytics::Aggregation).to receive(:load_batch).once.and_call_original
      end

      it 'does nothing' do
        freeze_time do
          aggregation = create(:cycle_analytics_aggregation, last_consistency_check_updated_at: 5.minutes.from_now)

          expect { worker.perform }.not_to change { aggregation.reload }
        end
      end
    end

    context 'when pending aggregation records present' do
      it 'invokes the consistency services' do
        aggregation1 = create(:cycle_analytics_aggregation, last_consistency_check_updated_at: 5.minutes.ago)
        aggregation2 = create(:cycle_analytics_aggregation, last_consistency_check_updated_at: 10.minutes.ago)

        freeze_time do
          worker.perform

          expect(aggregation1.reload.last_consistency_check_updated_at).to eq(Time.current)
          expect(aggregation2.reload.last_consistency_check_updated_at).to eq(Time.current)
        end
      end
    end

    context 'when worker is over time' do
      it 'breaks at the second iteration due to overtime, saving cursor information' do
        aggregation1 = create(:cycle_analytics_aggregation, last_consistency_check_updated_at: 15.minutes.ago)
        aggregation2 = create(:cycle_analytics_aggregation, last_consistency_check_updated_at: 10.minutes.ago)
        original_aggregation2_timestamp = aggregation2.reload.last_consistency_check_updated_at

        first_monotonic_time = 100
        second_monotonic_time = first_monotonic_time + described_class::MAX_RUNTIME.to_i + 10

        service_response = ServiceResponse.success

        expect(Gitlab::Metrics::System).to receive(:monotonic_time).and_return(first_monotonic_time, second_monotonic_time)
        expect(worker).to receive(:run_consistency_check_services).once.and_return(service_response)

        freeze_time do
          worker.perform

          expect(aggregation1.reload.last_consistency_check_updated_at).to eq(Time.current)
          expect(aggregation2.reload.last_consistency_check_updated_at).to eq(original_aggregation2_timestamp)
        end
      end
    end

    context 'when the service runs out of time' do
      it 'stops while processing a batch, saving cursor information, and restart from where it left on the next run' do
        aggregation1 = create(:cycle_analytics_aggregation, last_consistency_check_updated_at: 15.minutes.ago)
        aggregation2 = create(:cycle_analytics_aggregation, last_consistency_check_updated_at: 10.minutes.ago)
        original_aggregation1_timestamp = aggregation1.reload.last_consistency_check_updated_at
        original_aggregation2_timestamp = aggregation2.reload.last_consistency_check_updated_at

        issues_consistency_service_response = ServiceResponse.success(payload: {
          reason: :limit_reached,
          stage_event_hash_id: 123,
          model: ::Issue,
          cursor: {
            'start_event_timestamp' => 18.minutes.ago.floor(3),
            'end_event_timestamp' => 7.minutes.ago.floor(3),
            'issue_id' => 321
          }
        })
        issues_consistency_service = instance_double(Analytics::CycleAnalytics::ConsistencyCheckService)

        expect(Analytics::CycleAnalytics::ConsistencyCheckService).to receive(:new)
          .twice
          .with(group: aggregation1.group, event_model: Analytics::CycleAnalytics::IssueStageEvent)
          .and_return(issues_consistency_service)

        expect(issues_consistency_service).to receive(:execute).once.and_return(issues_consistency_service_response)

        freeze_time do
          worker.perform

          expect(aggregation1.reload.last_consistency_check_updated_at).to eq(original_aggregation1_timestamp)
          expect(aggregation1.last_consistency_check_issues_stage_event_hash_id).to eq(issues_consistency_service_response.payload[:stage_event_hash_id])
          expect(aggregation1.last_consistency_check_issues_start_event_timestamp).to eq(issues_consistency_service_response.payload[:cursor]['start_event_timestamp'])
          expect(aggregation1.last_consistency_check_issues_end_event_timestamp).to eq(issues_consistency_service_response.payload[:cursor]['end_event_timestamp'])
          expect(aggregation1.last_consistency_check_issues_issuable_id).to eq(issues_consistency_service_response.payload[:cursor]['issue_id'])

          expect(aggregation2.reload.last_consistency_check_updated_at).to eq(original_aggregation2_timestamp)
        end

        merge_requests_consistency_service_response = ServiceResponse.success(payload: {
          reason: :limit_reached,
          stage_event_hash_id: 1234,
          model: ::MergeRequest,
          cursor: {
            'start_event_timestamp' => 19.minutes.ago.floor(3),
            'end_event_timestamp' => 4.minutes.ago.floor(3),
            'merge_request_id' => 4321
          }
        })
        merge_requests_consistency_service = instance_double(Analytics::CycleAnalytics::ConsistencyCheckService)

        expect(Analytics::CycleAnalytics::ConsistencyCheckService).to receive(:new)
          .with(group: aggregation1.group, event_model: Analytics::CycleAnalytics::MergeRequestStageEvent)
          .and_return(merge_requests_consistency_service)

        expect(issues_consistency_service).to receive(:execute).once.and_return(ServiceResponse.success)
        expect(merge_requests_consistency_service).to receive(:execute).once.and_return(merge_requests_consistency_service_response)

        freeze_time do
          worker.perform

          expect(aggregation1.reload.last_consistency_check_updated_at).to eq(original_aggregation1_timestamp)

          expect(aggregation1.last_consistency_check_merge_requests_stage_event_hash_id).to eq(merge_requests_consistency_service_response.payload[:stage_event_hash_id])
          expect(aggregation1.last_consistency_check_merge_requests_start_event_timestamp).to eq(merge_requests_consistency_service_response.payload[:cursor]['start_event_timestamp'])
          expect(aggregation1.last_consistency_check_merge_requests_end_event_timestamp).to eq(merge_requests_consistency_service_response.payload[:cursor]['end_event_timestamp'])
          expect(aggregation1.last_consistency_check_merge_requests_issuable_id).to eq(merge_requests_consistency_service_response.payload[:cursor]['merge_request_id'])

          expect(aggregation1.last_consistency_check_issues_stage_event_hash_id).to be_nil
          expect(aggregation1.last_consistency_check_issues_start_event_timestamp).to be_nil
          expect(aggregation1.last_consistency_check_issues_end_event_timestamp).to be_nil
          expect(aggregation1.last_consistency_check_issues_issuable_id).to be_nil

          expect(aggregation2.reload.last_consistency_check_updated_at).to eq(original_aggregation2_timestamp)
        end
      end
    end
  end
end
