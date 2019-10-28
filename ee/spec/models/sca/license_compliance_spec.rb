# frozen_string_literal: true

require "spec_helper"

RSpec.describe SCA::LicenseCompliance do
  subject { described_class.new(project) }

  let(:project) { create(:project, :repository, :private) }

  before do
    stub_licensed_features(licenses_list: true, license_management: true)
  end

  describe "#policies" do
    context "when a pipeline has not been run for this project" do
      it { expect(subject.policies.count).to be_zero }

      context "when the project has policies configured" do
        let!(:mit) { create(:software_license, :mit) }
        let!(:mit_policy) { create(:software_license_policy, :denied, software_license: mit, project: project) }

        it { expect(subject.policies.count).to be(1) }
        it { expect(subject.policies[0]&.id).to eq(mit_policy.id) }
        it { expect(subject.policies[0]&.name).to eq(mit.name) }
        it { expect(subject.policies[0]&.url).to be_nil }
        it { expect(subject.policies[0]&.classification).to eq("denied") }
        it { expect(subject.policies[0]&.spdx_identifier).to eq("MIT") }
      end
    end

    context "when a pipeline has run" do
      let!(:pipeline) { create(:ci_pipeline, :success, project: project, builds: builds) }
      let(:builds) { [] }

      context "when a license scan job is not configured" do
        let(:builds) { [create(:ci_build, :success)] }

        it { expect(subject.policies).to be_empty }
      end

      context "when the license scan job has not finished" do
        let(:builds) { [create(:ci_build, :running, job_artifacts: [artifact])] }
        let(:artifact) { create(:ci_job_artifact, file_type: :license_management, file_format: :raw) }

        it { expect(subject.policies).to be_empty }
      end

      context "when the license scan produces a poorly formatted report" do
        let(:builds) { [create(:ci_build, :running, job_artifacts: [artifact])] }
        let(:artifact) { create(:ci_job_artifact, file_type: :license_management, file_format: :raw, file: invalid_file) }
        let(:invalid_file) { fixture_file_upload(Rails.root.join("ee/spec/fixtures/metrics.txt"), "text/plain") }

        before do
          artifact.update!(file: invalid_file)
        end

        it { expect(subject.policies).to be_empty }
      end

      context "when the dependency scan produces a poorly formatted report" do
        let(:builds) { [license_scan_build, dependency_scan_build] }
        let(:license_scan_build) { create(:ci_build, :success, job_artifacts: [license_scan_artifact]) }
        let(:license_scan_artifact) { create(:ci_job_artifact, file_type: :license_management, file_format: :raw) }
        let(:license_scan_file) { fixture_file_upload(Rails.root.join("ee/spec/fixtures/security_reports/gl-license-management-report-v2.json"), "application/json") }

        let(:dependency_scan_build) { create(:ci_build, :success, job_artifacts: [dependency_scan_artifact]) }
        let(:dependency_scan_artifact) { create(:ci_job_artifact, file_type: :dependency_scanning, file_format: :raw) }
        let(:invalid_file) { fixture_file_upload(Rails.root.join("ee/spec/fixtures/metrics.txt"), "text/plain") }

        before do
          license_scan_artifact.update!(file: license_scan_file)
          dependency_scan_artifact.update!(file: invalid_file)
        end

        it { expect(subject.policies.map(&:spdx_identifier)).to contain_exactly('BSD-3-Clause', 'MIT', nil) }
      end

      context "when a pipeline has successfully produced a license scan report" do
        let(:builds) { [license_scan_build] }
        let!(:mit) { create(:software_license, :mit) }
        let!(:mit_policy) { create(:software_license_policy, :denied, software_license: mit, project: project) }
        let!(:other_license) { create(:software_license, spdx_identifier: "Other-Id") }
        let!(:other_license_policy) { create(:software_license_policy, :allowed, software_license: other_license, project: project) }

        let(:license_scan_build) { create(:ci_build, :success, job_artifacts: [license_scan_artifact]) }
        let(:license_scan_artifact) { create(:ci_job_artifact, file_type: :license_management, file_format: :raw) }
        let(:license_scan_file) { fixture_file_upload(Rails.root.join("ee/spec/fixtures/security_reports/gl-license-management-report-v2.json"), "application/json") }

        before do
          license_scan_artifact.update!(file: license_scan_file)
        end

        it { expect(subject.policies.count).to eq(4) }

        it { expect(subject.policies[0]&.id).to be_nil }
        it { expect(subject.policies[0]&.name).to eq("BSD 3-Clause \"New\" or \"Revised\" License") }
        it { expect(subject.policies[0]&.url).to eq("http://spdx.org/licenses/BSD-3-Clause.json") }
        it { expect(subject.policies[0]&.classification).to eq("unclassified") }
        it { expect(subject.policies[0]&.spdx_identifier).to eq("BSD-3-Clause") }

        it { expect(subject.policies[1]&.id).to eq(mit_policy.id) }
        it { expect(subject.policies[1]&.name).to eq(mit.name) }
        it { expect(subject.policies[1]&.url).to eq("http://spdx.org/licenses/MIT.json") }
        it { expect(subject.policies[1]&.classification).to eq("denied") }
        it { expect(subject.policies[1]&.spdx_identifier).to eq("MIT") }

        it { expect(subject.policies[2]&.id).to eq(other_license_policy.id) }
        it { expect(subject.policies[2]&.name).to eq(other_license.name) }
        it { expect(subject.policies[2]&.url).to be_blank }
        it { expect(subject.policies[2]&.classification).to eq("allowed") }
        it { expect(subject.policies[2]&.spdx_identifier).to eq(other_license.spdx_identifier) }

        it { expect(subject.policies[3]&.id).to be_nil }
        it { expect(subject.policies[3]&.name).to eq("unknown") }
        it { expect(subject.policies[3]&.url).to be_blank }
        it { expect(subject.policies[3]&.classification).to eq("unclassified") }
        it { expect(subject.policies[3]&.spdx_identifier).to be_nil }
      end
    end
  end

  describe "#latest_build_for_default_branch" do
    let(:regular_build) { create(:ci_build, :success) }
    let(:license_scan_build) { create(:ci_build, :success, job_artifacts: [license_scan_artifact]) }
    let(:license_scan_artifact) { create(:ci_job_artifact, file_type: :license_management, file_format: :raw) }

    context "when a pipeline has never been completed for the project" do
      it { expect(subject.latest_build_for_default_branch).to be_nil }
    end

    context "when a pipeline has completed successfully and produced a license scan report" do
      let!(:pipeline) { create(:ci_pipeline, :success, project: project, builds: [regular_build, license_scan_build]) }

      it { expect(subject.latest_build_for_default_branch).to eq(license_scan_build) }
    end

    context "when a pipeline has completed but does not contain a license scan report" do
      let!(:pipeline) { create(:ci_pipeline, :success, project: project, builds: [regular_build]) }

      it { expect(subject.latest_build_for_default_branch).to be_nil }
    end
  end
end
