# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::IngestReportsService, feature_category: :vulnerability_management do
  let(:service_object) { described_class.new(pipeline) }

  let_it_be(:project) { create(:project) }
  let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
  let_it_be(:build) { create(:ci_build, pipeline: pipeline) }
  let_it_be(:security_scan_1) { create(:security_scan, build: build, scan_type: :sast) }
  let_it_be(:security_scan_2) { create(:security_scan, :with_error, build: build, scan_type: :dast) }
  let_it_be(:security_scan_3) { create(:security_scan, build: build, scan_type: :dependency_scanning) }
  let_it_be(:vulnerability_1) { create(:vulnerability, project: pipeline.project) }
  let_it_be(:vulnerability_2) { create(:vulnerability, project: pipeline.project) }
  let_it_be(:sast_scanner) { create(:vulnerabilities_scanner, project: project, external_id: 'find_sec_bugs') }
  let_it_be(:gemnasium_scanner) { create(:vulnerabilities_scanner, project: project, external_id: 'gemnasium-maven') }
  let_it_be(:sast_artifact) { create(:ee_ci_job_artifact, :sast, job: build, project: project) }
  let!(:dependency_scanning_artifact) { create(:ee_ci_job_artifact, :dependency_scanning, job: build, project: project) }

  describe '#execute' do
    let(:ids_1) { [vulnerability_1.id] }
    let(:ids_2) { [] }

    subject(:ingest_reports) { service_object.execute }

    before do
      allow(Security::Ingestion::IngestReportService).to receive(:execute).and_return(ids_1, ids_2)
      allow(Security::Ingestion::ScheduleMarkDroppedAsResolvedService).to receive(:execute)
      allow(Sbom::IngestReportsWorker).to receive(:perform_async)
    end

    it 'calls IngestReportService for each succeeded security scan', :aggregate_failures do
      ingest_reports

      expect(Security::Ingestion::IngestReportService).to have_received(:execute).twice
      expect(Security::Ingestion::IngestReportService).to have_received(:execute).once.with(security_scan_1)
      expect(Security::Ingestion::IngestReportService).to have_received(:execute).once.with(security_scan_3)
    end

    it 'sets the resolved vulnerabilities, latest pipeline ID and has_vulnerabilities flag' do
      expect { ingest_reports }.to change { project.reload.project_setting&.has_vulnerabilities }.to(true)
        .and change { project.reload.vulnerability_statistic&.latest_pipeline_id }.to(pipeline.id)
    end

    it 'calls ScheduleMarkDroppedAsResolvedService with primary identifier IDs' do
      ingest_reports

      expect(
        Security::Ingestion::ScheduleMarkDroppedAsResolvedService
      ).to have_received(:execute).with(project.id, 'sast', sast_artifact.security_report.primary_identifiers)
    end

    it 'marks vulnerabilities as resolved' do
      expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute).once.with(sast_scanner, ids_1)
      expect(Security::Ingestion::MarkAsResolvedService).to receive(:execute).once.with(gemnasium_scanner, [])
      ingest_reports
    end

    context 'when the same scanner is used into separate child pipelines' do
      let_it_be(:parent_pipeline) { create(:ee_ci_pipeline, :success, project: project) }
      let_it_be(:child_pipeline_1) { create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project) }
      let_it_be(:child_pipeline_2) { create(:ee_ci_pipeline, :success, child_of: parent_pipeline, project: project) }
      let_it_be(:parent_scan) { create(:security_scan, pipeline: parent_pipeline) }
      let_it_be(:scan_1) { create(:security_scan, pipeline: child_pipeline_1) }
      let_it_be(:scan_2) { create(:security_scan, pipeline: child_pipeline_2) }

      subject(:service_object) { described_class.new(parent_pipeline) }

      it 'ingests the scan from both child pipelines' do
        service_object.execute

        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(parent_scan)
        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(scan_1)
        expect(Security::Ingestion::IngestReportService).to have_received(:execute).with(scan_2)
      end
    end

    describe 'scheduling the AutoFix background job' do
      let(:auto_fix_dependency_scanning?) { false }

      before do
        allow(Security::AutoFixWorker).to receive(:perform_async)
        allow(project.security_setting).to receive(:auto_fix_enabled?).and_return(auto_fix_enabled?)
        project.security_setting.update!(auto_fix_container_scanning: false, auto_fix_dependency_scanning: auto_fix_dependency_scanning?)

        ingest_reports
      end

      context 'when the auto_fix is not enabled for the project' do
        let(:auto_fix_enabled?) { false }

        context 'when the pipeline does not have any auto fix enabled report type' do
          it 'does not schedule the background job' do
            expect(Security::AutoFixWorker).not_to have_received(:perform_async)
          end
        end

        context 'when the pipeline has an auto fix enabled report type' do
          let(:auto_fix_dependency_scanning?) { true }

          it 'does not schedule the background job' do
            expect(Security::AutoFixWorker).not_to have_received(:perform_async)
          end
        end
      end

      context 'when the auto_fix is enabled for the project' do
        let(:auto_fix_enabled?) { true }

        context 'when the pipeline does not have any auto fix enabled report type' do
          it 'does not schedule the background job' do
            expect(Security::AutoFixWorker).not_to have_received(:perform_async)
          end
        end

        context 'when the pipeline has an auto fix enabled report type' do
          let(:auto_fix_dependency_scanning?) { true }

          it 'does not schedule the background job' do
            expect(Security::AutoFixWorker).to have_received(:perform_async)
          end
        end
      end
    end

    describe 'scheduling the SyncFindingsToApprovalRulesWorker background job' do
      before do
        allow(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).to receive(:perform_async)
        stub_licensed_features(security_orchestration_policies: security_orchestration_policies_enabled)

        ingest_reports
      end

      context 'when the security_orchestration_policies is not licensed for the project' do
        let(:security_orchestration_policies_enabled) { false }

        it 'does not schedule the background job' do
          expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).not_to have_received(:perform_async)
        end
      end

      context 'when the security_orchestration_policies is licensed for the project' do
        let(:security_orchestration_policies_enabled) { true }

        it 'schedules the background job' do
          expect(Security::ScanResultPolicies::SyncFindingsToApprovalRulesWorker).to have_received(:perform_async).with(pipeline.id)
        end
      end
    end

    context 'when scheduling the Sbom::IngestReportsWorker' do
      let(:default_branch) { true }
      let(:can_ingest_sbom_reports) { true }

      before do
        allow(pipeline).to receive(:default_branch?).and_return(default_branch)
        allow(pipeline).to receive(:can_ingest_sbom_reports?).and_return(can_ingest_sbom_reports)
      end

      context 'with child pipeline' do
        before do
          allow(pipeline).to receive(:child?).and_return(true)
        end

        it 'does not schedule Sbom::IngestReportsWorker' do
          ingest_reports

          expect(Sbom::IngestReportsWorker).not_to have_received(:perform_async)
        end
      end

      context 'with a non-default branch' do
        let(:default_branch) { false }

        it 'does not schedule Sbom::IngestReportsWorker' do
          ingest_reports

          expect(Sbom::IngestReportsWorker).not_to have_received(:perform_async)
        end
      end

      context 'when it cannot ingest sbom reports' do
        let(:can_ingest_sbom_reports) { false }

        it 'does not schedule Sbom::IngestReportsWorker' do
          ingest_reports

          expect(Sbom::IngestReportsWorker).not_to have_received(:perform_async)
        end
      end

      it 'schedules Sbom::IngestReportsWorker' do
        ingest_reports

        expect(Sbom::IngestReportsWorker).to have_received(:perform_async).with(pipeline.id)
      end
    end
  end
end
