# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::JobArtifacts::DestroyAllExpiredService, :clean_gitlab_redis_shared_state do
  include ExclusiveLeaseHelpers

  describe '.execute' do
    subject { service.execute }

    let(:service) { described_class.new }

    let_it_be(:locked_pipeline) { create(:ci_pipeline, :artifacts_locked) }
    let_it_be(:pipeline) { create(:ci_pipeline, :unlocked) }
    let_it_be(:locked_job) { create(:ci_build, :success, pipeline: locked_pipeline) }
    let_it_be(:job) { create(:ci_build, :success, pipeline: pipeline) }
    let_it_be(:security_scan) { create(:security_scan, build: job) }
    let_it_be(:security_finding) { create(:security_finding, scan: security_scan) }

    context 'when artifact is expired' do
      context 'when artifact is not locked' do
        let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }
        let(:event_data) { { job_ids: [artifact.job_id] } }

        it 'destroys job artifact and the security finding', :sidekiq_inline do
          expect { subject }.to change { Ci::JobArtifact.count }.by(-1)
                            .and change { Security::Finding.count }.by(-1)
        end

        it 'publishes Ci::JobArtifactsDeletedEvent' do
          event = double(:event)

          expect(Ci::JobArtifactsDeletedEvent)
            .to receive(:new)
            .with(data: event_data)
            .and_return(event)

          expect(Gitlab::EventStore).to receive(:publish).with(event)

          subject
        end
      end

      context 'when artifact is locked' do
        let!(:artifact) { create(:ci_job_artifact, :expired, job: locked_job, locked: locked_job.pipeline.locked) }

        it 'does not destroy job artifact' do
          expect { subject }.to not_change { Ci::JobArtifact.count }
                            .and not_change { Security::Finding.count }
        end
      end
    end

    context 'when artifact is not expired' do
      let!(:artifact) { create(:ci_job_artifact, job: job, locked: job.pipeline.locked) }

      it 'does not destroy expired job artifacts' do
        expect { subject }.to not_change { Ci::JobArtifact.count }
                          .and not_change { Security::Finding.count }
      end
    end

    context 'when artifact is permanent' do
      let!(:artifact) { create(:ci_job_artifact, expire_at: nil, job: job, locked: job.pipeline.locked) }

      it 'does not destroy expired job artifacts' do
        expect { subject }.to not_change { Ci::JobArtifact.count }
                          .and not_change { Security::Finding.count }
      end
    end

    context 'when there are artifacts more than batch sizes' do
      before do
        stub_const('Ci::JobArtifacts::DestroyAllExpiredService::BATCH_SIZE', 1)
      end

      let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }
      let!(:second_job) { create(:ci_build, :success, pipeline: pipeline) }
      let!(:second_artifact) { create(:ci_job_artifact, :expired, job: second_job, locked: second_job.pipeline.locked) }
      let!(:second_security_scan) { create(:security_scan, build: second_job) }
      let!(:second_security_finding) { create(:security_finding, scan: second_security_scan) }

      it 'destroys all expired artifacts', :sidekiq_inline do
        expect { subject }.to change { Ci::JobArtifact.count }.by(-2)
                          .and change { Security::Finding.count }.by(-2)
      end
    end

    context 'when some artifacts are locked', :sidekiq_inline do
      let!(:artifact) { create(:ci_job_artifact, :expired, job: job, locked: job.pipeline.locked) }
      let!(:second_artifact) { create(:ci_job_artifact, :expired, job: locked_job, locked: locked_job.pipeline.locked) }

      it 'destroys only unlocked artifacts' do
        expect { subject }.to change { Ci::JobArtifact.count }.by(-1)
                          .and change { Security::Finding.count }.by(-1)
      end
    end
  end
end
