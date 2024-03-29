# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::RakeTaskExecutorService, :silence_stdout, feature_category: :global_search do
  let(:logger) { instance_double('Logger') }
  let(:service) { described_class.new(logger: logger) }

  describe '#execute' do
    it 'raises an exception when unknown task is provided' do
      expect { service.execute(:foo) }.to raise_error(ArgumentError)
    end

    it 'raises an exception when the task is not implemented' do
      stub_const('::Search::RakeTaskExecutorService::TASKS', [:foo])

      expect { service.execute(:foo) }.to raise_error(NotImplementedError)
    end

    described_class::TASKS.each do |task|
      it "executes #{task} task" do
        expect(service).to receive(task).and_return(true)

        service.execute(task)
      end
    end
  end

  describe '#index_snippets' do
    subject(:task) { service.execute(:index_snippets) }

    it 'indexes snippets' do
      expect(Snippet).to receive(:es_import)
      expect(logger).to receive(:info).with(/Indexing snippets/).twice

      task
    end
  end

  describe '#pause_indexing' do
    subject(:task) { service.execute(:pause_indexing) }

    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      allow(settings).to receive(:elasticsearch_pause_indexing?).and_return(indexing_paused)
    end

    context 'when indexing is already paused' do
      let(:indexing_paused) { true }

      it 'does not do anything' do
        expect(settings).not_to receive(:update!)
        expect { task }.to output(/Indexing is already paused/).to_stdout
      end
    end

    context 'when indexing is running' do
      let(:indexing_paused) { false }

      it 'pauses indexing' do
        expect(settings).to receive(:update!).with(elasticsearch_pause_indexing: true)
        expect { task }.to output(/Indexing is now paused/).to_stdout
      end
    end
  end

  describe '#resume_indexing' do
    subject(:task) { service.execute(:resume_indexing) }

    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      allow(settings).to receive(:elasticsearch_pause_indexing?).and_return(indexing_paused)
    end

    context 'when indexing is already running' do
      let(:indexing_paused) { false }

      it 'does not do anything' do
        expect(settings).not_to receive(:update!)
        expect { task }.to output(/Indexing is already running/).to_stdout
      end
    end

    context 'when indexing is not running' do
      let(:indexing_paused) { true }

      it 'resumes indexing' do
        expect(settings).to receive(:update!).with(elasticsearch_pause_indexing: false)
        expect { task }.to output(/Indexing is now running/).to_stdout
      end
    end
  end

  describe '#estimate_cluster_size' do
    subject(:task) { service.execute(:estimate_cluster_size) }

    before do
      create(:namespace_root_storage_statistics, repository_size: 1.megabyte)
      create(:namespace_root_storage_statistics, repository_size: 10.megabyte)
      create(:namespace_root_storage_statistics, repository_size: 30.megabyte)
    end

    it 'outputs estimates' do
      expect { task }.to output(/your cluster size should be at least 20.5 MiB/).to_stdout
    end
  end

  describe '#mark_reindex_failed' do
    subject(:task) { service.execute(:mark_reindex_failed) }

    context 'when there is a running reindex job' do
      before do
        Elastic::ReindexingTask.create!
      end

      it 'marks the current reindex job as failed' do
        expect { task }.to change { Elastic::ReindexingTask.running? }.from(true).to(false)
      end

      it 'prints a message after marking it as failed' do
        expect { task }.to output("Marked the current reindexing job as failed.\n").to_stdout
      end
    end

    context 'when no running reindex job' do
      it 'just prints a message' do
        expect { task }.to output("Did not find the current running reindexing job.\n").to_stdout
      end
    end
  end

  describe '#list_pending_migrations' do
    subject(:task) { service.execute(:list_pending_migrations) }

    context 'when there are pending migrations' do
      let(:pending_migrations) { ::Elastic::DataMigrationService.migrations.last(2) }
      let(:pending_migration1) { pending_migrations.first }
      let(:pending_migration2) { pending_migrations.second }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return(pending_migrations)
      end

      it 'outputs pending migrations' do
        expect { task }.to output(/#{pending_migration1.name}\n#{pending_migration2.name}/).to_stdout
      end
    end

    context 'when there is no pending migrations' do
      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([])
      end

      it 'outputs message there are no pending migrations' do
        expect { task }.to output(/There are no pending migrations./).to_stdout
      end
    end

    context 'when pending migrations are obsolete' do
      let(:obsolete_pending_migration) { ::Elastic::DataMigrationService.migrations.first }

      before do
        allow(::Elastic::DataMigrationService).to receive(:pending_migrations).and_return([obsolete_pending_migration])
        allow(obsolete_pending_migration).to receive(:obsolete?).and_return(true)
      end

      it 'outputs that the pending migration is obsolete' do
        expect { task }.to output(/#{obsolete_pending_migration.name} \[Obsolete\]/).to_stdout
      end
    end
  end

  describe '#enable_search_with_elasticsearch' do
    subject(:task) { service.execute(:enable_search_with_elasticsearch) }

    let(:settings) { ::Gitlab::CurrentSettings }

    before do
      settings.update!(elasticsearch_search: es_enabled)
    end

    context 'when enabling elasticsearch with setting initially off' do
      let(:es_enabled) { false }

      it 'enables elasticsearch' do
        expect { task }.to change { settings.elasticsearch_search }.from(false).to(true)
      end
    end

    context 'when enabling elasticsearch with setting initially on' do
      let(:es_enabled) { true }

      it 'does nothing when elasticsearch is already enabled' do
        expect { task }.not_to change { settings.elasticsearch_search }
      end
    end
  end

  describe '#index_projects_status' do
    subject(:task) { service.execute(:index_projects_status) }

    let_it_be(:project) { create(:project, :repository) }
    let_it_be(:project_no_repository) { create(:project) }
    let_it_be(:project_empty_repository) { create(:project, :empty_repo) }

    context 'when some projects missing from index' do
      before do
        create(:index_status, project: project)
      end

      it 'displays completion percentage' do
        expected = <<~STD_OUT
          Indexing is 33.33% complete (1/3 projects)
        STD_OUT

        expect { task }.to output(expected).to_stdout
      end

      context 'when elasticsearch_limit_indexing? is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        it 'only displays non-indexed projects that are setup for indexing' do
          create(:elasticsearch_indexed_project, project: project_no_repository)

          expected = <<~STD_OUT
            Indexing is 0.00% complete (0/1 projects)
          STD_OUT

          expect { task }.to output(expected).to_stdout
        end
      end
    end

    context 'when all projects are indexed' do
      before do
        create(:index_status, project: project)
        create(:index_status, project: project_no_repository)
        create(:index_status, project: project_empty_repository)
      end

      it 'displays that all projects are indexed' do
        expected = <<~STD_OUT
          Indexing is 100.00% complete (3/3 projects)
        STD_OUT

        expect { task }.to output(expected).to_stdout
      end

      context 'when elasticsearch_limit_indexing? is enabled' do
        before do
          stub_ee_application_setting(elasticsearch_limit_indexing: true)
        end

        it 'only displays non-indexed projects that are setup for indexing' do
          create(:elasticsearch_indexed_project, project: project_empty_repository)

          expected = <<~STD_OUT
            Indexing is 100.00% complete (1/1 projects)
          STD_OUT

          expect { task }.to output(expected).to_stdout
        end
      end
    end
  end

  describe '#index_users' do
    subject(:task) { service.execute(:index_users) }

    let!(:users) { create_list(:user, 2) }

    it 'queues jobs for all users' do
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:track!).with(*users).once

      task
    end
  end

  describe '#index_projects' do
    subject(:task) { service.execute(:index_projects) }

    let(:project1) { create :project }
    let(:project2) { create :project }
    let(:project3) { create :project }

    before do
      Sidekiq::Testing.disable! do
        project1
        project2
      end
    end

    it 'queues jobs for each project batch' do
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(project1, project2)

      task
    end

    context 'with limited indexing enabled' do
      before do
        Sidekiq::Testing.disable! do
          project1
          project2
          project3

          create :elasticsearch_indexed_project, project: project1
          create :elasticsearch_indexed_namespace, namespace: project3.namespace
        end

        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      it 'does not queue jobs for projects that should not be indexed' do
        expect(Elastic::ProcessInitialBookkeepingService).to receive(:backfill_projects!).with(project1, project3)

        task
      end
    end
  end

  describe '#index_epics' do
    subject(:task) { service.execute(:index_epics) }

    let!(:epic) { create(:epic) }

    it 'calls maintain_indexed_group_associations for groups' do
      expect(Elastic::ProcessInitialBookkeepingService).to receive(:maintain_indexed_group_associations!)
        .with(epic.group)

      task
    end

    context 'with limited indexing enabled' do
      let!(:group1) { create(:group) }
      let!(:group2) { create(:group) }
      let!(:group3) { create(:group) }

      before do
        create(:elasticsearch_indexed_namespace, namespace: group1)
        create(:elasticsearch_indexed_namespace, namespace: group3)

        stub_ee_application_setting(elasticsearch_limit_indexing: true)
      end

      it 'does not call maintain_indexed_group_associations for groups that should not be indexed' do
        expect(Elastic::ProcessBookkeepingService).to receive(:maintain_indexed_group_associations!)
          .with(group1, group3)

        task
      end
    end
  end
end
