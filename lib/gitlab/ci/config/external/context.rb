# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module External
        class Context
          include Gitlab::Utils::StrongMemoize

          TimeoutError = Class.new(StandardError)

          MAX_INCLUDES = 100
          NEW_MAX_INCLUDES = 150 # Update to MAX_INCLUDES when FF ci_includes_count_duplicates is removed

          include ::Gitlab::Utils::StrongMemoize

          attr_reader :project, :sha, :user, :parent_pipeline, :variables, :pipeline_config
          attr_reader :expandset, :execution_deadline, :logger, :max_includes

          delegate :instrument, to: :logger

          def initialize(
            project: nil, sha: nil, user: nil, parent_pipeline: nil, variables: nil,
            pipeline_config: nil, logger: nil
          )
            @project = project
            @sha = sha
            @user = user
            @parent_pipeline = parent_pipeline
            @variables = variables || Ci::Variables::Collection.new
            @pipeline_config = pipeline_config
            @expandset = Feature.enabled?(:ci_includes_count_duplicates, project) ? [] : Set.new
            @execution_deadline = 0
            @logger = logger || Gitlab::Ci::Pipeline::Logger.new(project: project)
            @max_includes = Feature.enabled?(:ci_includes_count_duplicates, project) ? NEW_MAX_INCLUDES : MAX_INCLUDES
            yield self if block_given?
          end

          def top_level_worktree_paths
            strong_memoize(:top_level_worktree_paths) do
              project.repository.tree(sha).blobs.map(&:path)
            end
          end

          def all_worktree_paths
            strong_memoize(:all_worktree_paths) do
              project.repository.ls_files(sha)
            end
          end

          def variables_hash
            strong_memoize(:variables_hash) do
              variables.to_hash
            end
          end

          def mutate(attrs = {})
            self.class.new(**attrs) do |ctx|
              ctx.expandset = expandset
              ctx.execution_deadline = execution_deadline
              ctx.logger = logger
              ctx.max_includes = max_includes
            end
          end

          def set_deadline(timeout_seconds)
            @execution_deadline = current_monotonic_time + timeout_seconds.to_f
          end

          def check_execution_time!
            raise TimeoutError if execution_expired?
          end

          def sentry_payload
            {
              user: user.inspect,
              project: project.inspect
            }
          end

          def mask_variables_from(string)
            variables.reduce(string.dup) do |str, variable|
              if variable[:masked]
                Gitlab::Ci::MaskSecret.mask!(str, variable[:value])
              else
                str
              end
            end
          end

          def includes
            expandset.map(&:metadata)
          end

          # Some ProjectConfig sources inject an `include` into the config content. We use this
          # method to exclude that `include` from the calculation of the total included files.
          def contains_internal_include?
            !!pipeline_config&.contains_internal_include?
          end

          protected

          attr_writer :expandset, :execution_deadline, :logger, :max_includes

          private

          def current_monotonic_time
            Gitlab::Metrics::System.monotonic_time
          end

          def execution_expired?
            return false if execution_deadline == 0

            current_monotonic_time > execution_deadline
          end
        end
      end
    end
  end
end
