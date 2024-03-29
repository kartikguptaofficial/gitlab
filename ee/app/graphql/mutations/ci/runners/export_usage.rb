# frozen_string_literal: true

module Mutations
  module Ci
    module Runners
      class ExportUsage < BaseMutation
        graphql_name 'RunnersExportUsage'

        DEFAULT_PROJECT_COUNT = 1_000

        argument :type, ::Types::Ci::RunnerTypeEnum,
          required: false,
          description: 'Scope of the runners to include in the report.'

        argument :from_date, ::GraphQL::Types::ISO8601Date,
          required: false,
          description: 'UTC start date of the period to report on. Defaults to the start of last full month.'
        argument :to_date, ::GraphQL::Types::ISO8601Date,
          required: false,
          description: 'UTC end date of the period to report on. " \
            "Defaults to the end of the month specified by `fromDate`.'

        argument :max_project_count, ::GraphQL::Types::Int,
          required: false,
          default_value: DEFAULT_PROJECT_COUNT,
          description:
            "Maximum number of projects to return. All other runner usage will be attributed " \
            "to a '<Other projects>' entry. Defaults to #{DEFAULT_PROJECT_COUNT} projects."

        def ready?(**args)
          raise_resource_not_available_error! unless Ability.allowed?(current_user, :read_runner_usage)

          max_project_count = args.fetch(:max_project_count, DEFAULT_PROJECT_COUNT)

          unless max_project_count.between?(1, ::Ci::Runners::GenerateUsageCsvService::MAX_PROJECT_COUNT)
            raise Gitlab::Graphql::Errors::ArgumentError,
              "maxProjectCount must be between 1 and #{::Ci::Runners::GenerateUsageCsvService::MAX_PROJECT_COUNT}"
          end

          super
        end

        def resolve(type: nil, from_date: nil, to_date: nil, max_project_count: nil)
          from_date ||= Date.current.prev_month.beginning_of_month
          to_date ||= from_date.end_of_month

          args = {
            runner_type: ::Ci::Runner.runner_types[type],
            from_date: from_date,
            to_date: to_date,
            max_project_count: max_project_count
          }

          ::Ci::Runners::ExportUsageCsvWorker.perform_async(current_user.id, args) # rubocop: disable CodeReuse/Worker -- this worker sends out emails

          {
            errors: []
          }
        end
      end
    end
  end
end
