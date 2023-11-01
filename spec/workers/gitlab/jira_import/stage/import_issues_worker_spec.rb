# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::JiraImport::Stage::ImportIssuesWorker, feature_category: :importers do
  include JiraIntegrationHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, import_type: 'jira') }

  describe 'modules' do
    it_behaves_like 'include import workers modules'
  end

  describe '#perform' do
    let_it_be(:jira_import, reload: true) { create(:jira_import_state, :scheduled, project: project) }

    before do
      stub_jira_integration_test
    end

    context 'when import did not start' do
      it_behaves_like 'cannot do Jira import'
      it_behaves_like 'does not advance to next stage'
    end

    context 'when import started', :clean_gitlab_redis_cache do
      let(:job_waiter) { Gitlab::JobWaiter.new(2, 'some-job-key') }

      before_all do
        create(:jira_integration, project: project)
      end

      before do
        jira_import.start!
        allow_next_instance_of(Gitlab::JiraImport::IssuesImporter) do |instance|
          allow(instance).to receive(:fetch_issues).and_return([])
        end
      end

      it 'uses a custom http client for the issues importer' do
        jira_integration = project.jira_integration
        client = instance_double(JIRA::Client)
        issue_importer = instance_double(Gitlab::JiraImport::IssuesImporter)

        allow(Project).to receive(:find_by_id).with(project.id).and_return(project)
        allow(issue_importer).to receive(:execute).and_return(job_waiter)

        expect(jira_integration).to receive(:client).with(read_timeout: 2.minutes).and_return(client)
        expect(Gitlab::JiraImport::IssuesImporter).to receive(:new).with(
          project,
          client
        ).and_return(issue_importer)

        described_class.new.perform(project.id)
      end

      context 'when increase_jira_import_issues_timeout feature flag is disabled' do
        before do
          stub_feature_flags(increase_jira_import_issues_timeout: false)
        end

        it 'does not provide a custom client to IssuesImporter' do
          issue_importer = instance_double(Gitlab::JiraImport::IssuesImporter)
          expect(Gitlab::JiraImport::IssuesImporter).to receive(:new).with(
            instance_of(Project),
            nil
          ).and_return(issue_importer)
          allow(issue_importer).to receive(:execute).and_return(job_waiter)

          described_class.new.perform(project.id)
        end
      end

      context 'when start_at is nil' do
        it_behaves_like 'advance to next stage', :attachments
      end

      context 'when start_at is zero' do
        before do
          allow(Gitlab::Cache::Import::Caching).to receive(:read).and_return(0)
        end

        it_behaves_like 'advance to next stage', :issues
      end

      context 'when start_at is greater than zero' do
        before do
          allow(Gitlab::Cache::Import::Caching).to receive(:read).and_return(25)
        end

        it_behaves_like 'advance to next stage', :issues
      end

      context 'when start_at is below zero' do
        before do
          allow(Gitlab::Cache::Import::Caching).to receive(:read).and_return(-1)
        end

        it_behaves_like 'advance to next stage', :attachments
      end
    end
  end
end
