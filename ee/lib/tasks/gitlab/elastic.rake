# frozen_string_literal: true

namespace :gitlab do
  namespace :elastic do
    desc "GitLab | Elasticsearch | Index everything at once"
    task index: :environment do
      raise 'This task cannot be run on GitLab.com' if Gitlab.com?

      if Gitlab::CurrentSettings.elasticsearch_pause_indexing
        puts "WARNING: `elasticsearch_pause_indexing` is enabled. " \
             "Disable this setting by running `rake gitlab:elastic:resume_indexing` " \
             "to complete indexing.".color(:yellow)
      end

      Rake::Task["gitlab:elastic:recreate_index"].invoke
      Rake::Task["gitlab:elastic:clear_index_status"].invoke

      # enable `elasticsearch_indexing` if it isn't
      unless Gitlab::CurrentSettings.elasticsearch_indexing?
        ApplicationSettings::UpdateService.new(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { elasticsearch_indexing: true }
        ).execute

        puts "Setting `elasticsearch_indexing` has been enabled."
      end

      Rake::Task["gitlab:elastic:index_group_entities"].invoke
      Rake::Task["gitlab:elastic:index_projects"].invoke
      Rake::Task["gitlab:elastic:index_snippets"].invoke
      Rake::Task["gitlab:elastic:index_users"].invoke
    end

    desc 'GitLab | Elasticsearch | Index Group entities'
    task index_group_entities: :environment do
      raise 'This task cannot be run on GitLab.com' if Gitlab.com?

      puts 'Enqueuing Group level entities…'
      Rake::Task["gitlab:elastic:index_epics"].invoke
      Rake::Task["gitlab:elastic:index_group_wikis"].invoke
    end

    desc 'GitLab | Elasticsearch | Enable Elasticsearch search'
    task enable_search_with_elasticsearch: :environment do
      tasks.execute(:enable_search_with_elasticsearch)
    end

    desc 'GitLab | Elasticsearch | Disable Elasticsearch search'
    task disable_search_with_elasticsearch: :environment do
      if Gitlab::CurrentSettings.elasticsearch_search?
        ApplicationSettings::UpdateService.new(
          Gitlab::CurrentSettings.current_application_settings,
          nil,
          { elasticsearch_search: false }
        ).execute

        puts "Setting `elasticsearch_search` has been disabled."
      else
        puts "Setting `elasticsearch_search` was already disabled."
      end
    end

    desc "GitLab | Elasticsearch | Index projects in the background"
    task index_projects: :environment do
      tasks.execute(:index_projects)
    end

    desc "GitLab | Elasticsearch | Overall indexing status of project repository data (code, commits, and wikis)"
    task index_projects_status: :environment do
      tasks.execute(:index_projects_status)
    end

    desc "GitLab | Elasticsearch | Index all snippets"
    task index_snippets: :environment do
      tasks.execute(:index_snippets)
    end

    desc "GitLab | Elasticsearch | Index all users"
    task index_users: :environment do
      tasks.execute(:index_users)
    end

    desc "GitLab | Elasticsearch | Index epics"
    task index_epics: :environment do
      tasks.execute(:index_epics)
    end

    desc "GitLab | Elasticsearch | Index group wikis"
    task index_group_wikis: :environment do
      raise 'This task cannot be run on GitLab.com' if Gitlab.com?

      logger = Logger.new($stdout)
      logger.info("Indexing group wikis...")

      group_ids = if Gitlab::CurrentSettings.elasticsearch_limit_indexing?
                    sql = 'INNER JOIN group_wiki_repositories ON namespaces.id = group_wiki_repositories.group_id'
                    Gitlab::CurrentSettings.elasticsearch_limited_namespaces.where(type: 'Group').joins(sql).pluck(:id)
                  else
                    GroupWikiRepository.pluck(:group_id)
                  end

      group_ids.each { |group_id| ::ElasticWikiIndexerWorker.perform_async(group_id, 'Group', force: true) }

      logger.info("Indexing group wikis... #{'done'.color(:green)}")
    end

    desc "GitLab | Elasticsearch | Create empty indexes and assigns an alias for each"
    task create_empty_index: [:environment] do |_t, _args|
      with_alias = ENV["SKIP_ALIAS"].nil?
      options = {}

      helper = Gitlab::Elastic::Helper.default
      index_name = helper.create_empty_index(with_alias: with_alias, options: options)

      # with_alias is used to support interacting with a specific index (such as when reclaiming the production index
      # name when the index was created prior to 13.0). If the `SKIP_ALIAS` environment variable is set,
      # do not create standalone indexes and do not create the migrations index
      if with_alias
        standalone_index_names = helper.create_standalone_indices(options: options)
        standalone_index_names.each do |index_name, alias_name|
          puts "Index '#{index_name}' has been created.".color(:green)
          puts "Alias '#{alias_name}' -> '#{index_name}' has been created.".color(:green)
        end

        helper.create_migrations_index unless helper.migrations_index_exists?
        ::Elastic::DataMigrationService.mark_all_as_completed!
      end

      puts "Index '#{index_name}' has been created.".color(:green)
      puts "Alias '#{helper.target_name}' → '#{index_name}' has been created".color(:green) if with_alias
    end

    desc "GitLab | Elasticsearch | Delete all indexes"
    task delete_index: [:environment] do |_t, _args|
      helper = Gitlab::Elastic::Helper.default

      if helper.delete_index
        puts "Index/alias '#{helper.target_name}' has been deleted".color(:green)
      else
        puts "Index/alias '#{helper.target_name}' was not found".color(:green)
      end

      results = helper.delete_standalone_indices
      results.each do |index_name, alias_name, result|
        if result
          puts "Index '#{index_name}' with alias '#{alias_name}' has been deleted".color(:green)
        else
          puts "Index '#{index_name}' with alias '#{alias_name}' was not found".color(:green)
        end
      end

      if helper.delete_migrations_index
        puts "Index/alias '#{helper.migrations_index_name}' has been deleted".color(:green)
      else
        puts "Index/alias '#{helper.migrations_index_name}' was not found".color(:green)
      end
    end

    desc "GitLab | Elasticsearch | Recreate indexes"
    task recreate_index: [:environment] do |_t, args|
      Rake::Task["gitlab:elastic:delete_index"].invoke(*args)
      Rake::Task["gitlab:elastic:create_empty_index"].invoke(*args)
    end

    desc "GitLab | Elasticsearch | Zero-downtime cluster reindexing"
    task reindex_cluster: :environment do
      trigger_cluster_reindexing
    end

    desc "GitLab | Elasticsearch | Clear indexing status"
    task clear_index_status: :environment do
      IndexStatus.delete_all
      Elastic::GroupIndexStatus.delete_all
      puts "Index status has been reset".color(:green)
    end

    desc "GitLab | Elasticsearch | Display which projects are not indexed"
    task projects_not_indexed: :environment do
      not_indexed = []

      ::Search::ElasticProjectsNotIndexedFinder.execute.each_batch do |batch|
        batch.inc_routes.each do |project|
          not_indexed << project
        end
      end

      if not_indexed.empty?
        puts 'All projects are currently indexed'.color(:green)
      else
        display_unindexed(not_indexed)
      end
    end

    desc "GitLab | Elasticsearch | Mark last reindexing job as failed"
    task mark_reindex_failed: :environment do
      tasks.execute(:mark_reindex_failed)
    end

    desc "GitLab | Elasticsearch | List pending migrations"
    task list_pending_migrations: :environment do
      tasks.execute(:list_pending_migrations)
    end

    desc "GitLab | Elasticsearch | Estimate Cluster size"
    task estimate_cluster_size: :environment do
      tasks.execute(:estimate_cluster_size)
    end

    desc "GitLab | Elasticsearch | Pause indexing"
    task pause_indexing: :environment do
      tasks.execute(:pause_indexing)
    end

    desc "GitLab | Elasticsearch | Resume indexing"
    task resume_indexing: :environment do
      tasks.execute(:resume_indexing)
    end

    desc "GitLab | Elasticsearch | List information about Advanced Search integration"
    task info: :environment do
      helper = Gitlab::Elastic::Helper.default
      setting = ApplicationSetting.current

      puts ""
      puts "Advanced Search".color(:yellow)
      puts "Server version:\t\t\t#{helper.server_info[:version] || 'unknown'.color(:red)}"
      puts "Server distribution:\t\t#{helper.server_info[:distribution] || 'unknown'.color(:red)}"
      puts "Indexing enabled:\t\t#{setting.elasticsearch_indexing? ? 'yes'.color(:green) : 'no'}"
      puts "Search enabled:\t\t\t#{setting.elasticsearch_search? ? 'yes'.color(:green) : 'no'}"
      puts "Requeue Indexing workers:\t#{setting.elasticsearch_requeue_workers? ? 'yes'.color(:green) : 'no'}"
      puts "Pause indexing:\t\t\t#{setting.elasticsearch_pause_indexing? ? 'yes'.color(:yellow) : 'no'}"
      puts "Indexing restrictions enabled:\t#{setting.elasticsearch_limit_indexing? ? 'yes'.color(:yellow) : 'no'}"
      puts "File size limit:\t\t#{setting.elasticsearch_indexed_file_size_limit_kb} KiB"
      puts "Indexing number of shards:\t#{Elastic::ProcessBookkeepingService.active_number_of_shards}"

      puts ""
      puts "Indexing Queues".color(:yellow)
      puts "Initial queue:\t\t\t#{::Elastic::ProcessInitialBookkeepingService.queue_size}"
      puts "Incremental queue:\t\t#{::Elastic::ProcessBookkeepingService.queue_size}"

      check_handler do
        pending_migrations = ::Elastic::DataMigrationService.pending_migrations

        if pending_migrations.any?
          puts ""
          display_pending_migrations(pending_migrations)
        end
      end

      check_handler do
        current_migration = ::Elastic::MigrationRecord.current_migration

        if current_migration
          current_state = current_migration.load_state

          puts ""
          puts "Current Migration".color(:yellow)
          puts "Name:\t\t\t#{current_migration.name}"
          puts "Started:\t\t#{current_migration.started? ? 'yes'.color(:green) : 'no'}"
          puts "Halted:\t\t\t#{current_migration.halted? ? 'yes'.color(:red) : 'no'.color(:green)}"
          puts "Failed:\t\t\t#{current_migration.failed? ? 'yes'.color(:red) : 'no'.color(:green)}"
          puts "Obsolete:\t\t#{current_migration.obsolete? ? 'yes'.color(:red) : 'no'.color(:green)}"
          puts "Current state:\t\t#{current_state.to_json}" if current_state.present?
        end
      end

      puts ""
      puts "Indices".color(:yellow)
      indices = ::Elastic::IndexSetting.order(:alias_name).pluck(:alias_name)
      indices.each do |alias_name|
        setting = begin
          helper.client.indices.get_settings(index: alias_name)
        rescue StandardError
          puts "  - failed to load indices for #{alias_name}".color(:red)
          {}
        end

        setting.sort.each do |index_name, hash|
          puts "- #{index_name}:"
          puts "  number_of_shards: #{hash.dig('settings', 'index', 'number_of_shards')}"
          puts "  number_of_replicas: #{hash.dig('settings', 'index', 'number_of_replicas')}"
          refresh_interval = hash.dig('settings', 'index', 'refresh_interval')
          puts "  refresh_interval: #{refresh_interval}" if refresh_interval
          (hash.dig('settings', 'index', 'blocks') || {}).each do |block, value|
            next unless value == 'true'

            puts "  blocks.#{block}: yes".color(:red)
          end
        end
      end
    end

    def check_handler
      yield
    rescue StandardError => e
      puts "An exception occurred during the retrieval of the data: #{e.class}: #{e.message}".color(:red)
    end

    def trigger_cluster_reindexing
      ::Elastic::ReindexingTask.create!

      ::ElasticClusterReindexingCronWorker.perform_async

      puts 'Reindexing job was successfully scheduled'.color(:green)
    rescue PG::UniqueViolation, ActiveRecord::RecordNotUnique
      puts 'There is another task in progress. Please wait for it to finish.'.color(:red)
    end

    def display_unindexed(projects)
      arr = if projects.count < 500 || ENV['SHOW_ALL']
              projects
            else
              projects[1..500]
            end

      arr.each { |p| puts "Project '#{p.full_path}' (ID: #{p.id}) isn't indexed.".color(:red) }

      puts "#{arr.count} out of #{projects.count} non-indexed projects shown."
    end

    def display_pending_migrations(pending_migrations)
      puts "Pending Migrations".color(:yellow)
      pending_migrations.each do |migration|
        migration_info = migration.name
        migration_info << " [Obsolete]".color(:red) if migration.obsolete?
        puts migration_info
      end
    end

    def tasks
      Search::RakeTaskExecutorService.new(logger: Logger.new($stdout))
    end
  end
end
