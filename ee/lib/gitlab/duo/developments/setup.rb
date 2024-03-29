# frozen_string_literal: true

# rubocop:disable Gitlab/DocUrl -- Development purpose
module Gitlab
  module Duo
    module Developments
      class Setup
        attr_reader :args

        def initialize(args)
          @args = args
        end

        def execute
          validates!

          ensure_feature_flags
          ensure_application_settings
          group = ensure_group
          ensure_license_activated(group)
          ensure_group_settings(group)
          ensure_embeddings

          print_output(group)
        end

        def validates!
          puts "Validating settings...."

          unless ::Gitlab.dev_or_test_env?
            raise <<~MSG
              Setup can only be performed in development or test environment, however, the current environment is #{ENV['RAILS_ENV']}.
            MSG
          end

          unless ::Gitlab::Utils.to_boolean(ENV['GITLAB_SIMULATE_SAAS'])
            raise <<~MSG
              Make sure 'GITLAB_SIMULATE_SAAS' environment variable is truthy.
              See https://docs.gitlab.com/ee/development/ee_features.html#simulate-a-saas-instance for more information.
            MSG
          end

          unless ::Gitlab::CurrentSettings.anthropic_api_key.present?
            raise <<~MSG
              Make sure Anthropic API key is correc]tly set.
              See https://docs.gitlab.com/ee/development/ai_features/index.html#configure-anthropic-access for more information.
            MSG
          end

          unless ::Gitlab::Llm::VertexAi::TokenLoader.new.current_token.present?
            raise <<~MSG
              Make sure Vertex AI access is correctly setup.
              See https://docs.gitlab.com/ee/development/ai_features/index.html#configure-gcp-vertex-access for more information.
            MSG
          end

          unless Gitlab::Database.has_config?(:embedding) # rubocop:disable Style/GuardClause -- Align guard clauses
            raise <<~MSG
              Make sure embedding database is setup.
              See https://docs.gitlab.com/ee/development/ai_features/index.html#set-up-the-embedding-database for more information.
            MSG
          end
        end

        def ensure_feature_flags
          puts "Enabling feature flags...."

          ::Feature.enable(:ai_global_switch)
          ::Feature.enable(:summarize_diff_automatically)
          ::Feature.enable(:summarize_my_code_review)
          ::Feature.enable(:automatically_summarize_mr_review)
          ::Feature.enable(:fill_in_mr_template)
        end

        def ensure_application_settings
          puts "Enabling application settings...."

          Gitlab::CurrentSettings.current_application_settings.update!(check_namespace_plan: true)
        end

        def ensure_group
          puts "Checking the specified group exists...."

          raise "You must specify :root_group_path" unless args[:root_group_path].present?
          raise "Sub group cannot be specified" if args[:root_group_path].include?('/')

          group = Group.find_by_full_path(args[:root_group_path])

          if group
            puts "Found the group: #{group.name}"
            return group
          end

          puts "The specified group is not found. Creating a new one..."

          current_user = User.first
          group_params = {
            name: args[:root_group_path],
            path: args[:root_group_path],
            visibility_level: ::Featurable::ENABLED
          }
          group = Groups::CreateService.new(current_user, group_params).execute

          raise "Failed to create a group: #{group.errors.full_messages}" unless group.persisted?

          group
        end

        # rubocop:disable CodeReuse/ActiveRecord -- Development purpose
        def ensure_license_activated(group)
          puts "Activating an Ultimate license to the group...."

          plan = Plan.find_or_create_by(name: "ultimate", title: "Ultimate")

          GitlabSubscription.find_or_create_by(namespace: group, hosted_plan: plan).tap do |subscription|
            GitlabSubscription.where(namespace: group).update_all(hosted_plan_id: plan.id) if subscription.errors.any?
          end
        end
        # rubocop:enable CodeReuse/ActiveRecord

        def ensure_group_settings(group)
          puts "Enabling the group settings...."

          group = Group.find(group.id) # Hard Reload for refreshing the cache
          group.update!(experiment_features_enabled: true)
        end

        def ensure_embeddings
          if ::Embedding::Vertex::GitlabDocumentation.count > 0
            puts "Embeddings of GitLab Documentations already exist. Skipping...."
            return
          end

          puts "Embeddings of GitLab Documentations do not exist. Seeding...."

          ::Rake::Task['gitlab:llm:embeddings:vertex:seed'].invoke
        end

        def print_output(group)
          puts <<~MSG
            ----------------------------------------
            Setup Complete!
            ----------------------------------------

            Visit "#{Gitlab.config.gitlab.protocol}://#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/#{group.full_path}" for testing GitLab Duo features.

            All GitLab Duo features except Code Suggestions should be available under the root group.
            To setup Code Suggestions, see https://docs.gitlab.com/ee/development/code_suggestions/.

            For more development guidelines, see https://docs.gitlab.com/ee/development/ai_features/index.html.
          MSG
        end
      end
    end
  end
end
# rubocop:enable Gitlab/DocUrl
