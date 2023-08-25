# frozen_string_literal: true

module Resolvers
  module Ci
    class AllJobsResolver < BaseResolver
      include LooksAhead

      type ::Types::Ci::JobType.connection_type, null: true

      argument :statuses, [::Types::Ci::JobStatusEnum],
              required: false,
              description: 'Filter jobs by status.'

      argument :runner_types, [::Types::Ci::RunnerTypeEnum],
              required: false,
              alpha: { milestone: '16.4' },
              description: 'Filter jobs by runner type if ' \
                           'feature flag `:admin_jobs_filter_runner_type` is enabled.'

      def resolve_with_lookahead(statuses: nil, runner_types: nil)
        jobs = ::Ci::JobsFinder.new(current_user: current_user,
params: { scope: statuses, runner_type: runner_types }).execute

        apply_lookahead(jobs)
      end

      private

      def preloads
        {
          previous_stage_jobs_or_needs: [:needs, :pipeline],
          artifacts: [:job_artifacts],
          pipeline: [:user],
          kind: [:metadata],
          retryable: [:metadata],
          project: [{ project: [:route, { namespace: [:route] }] }],
          commit_path: [:pipeline, { project: { namespace: [:route] } }],
          ref_path: [{ project: [:route, { namespace: [:route] }] }],
          browse_artifacts_path: [{ project: { namespace: [:route] } }],
          play_path: [{ project: { namespace: [:route] } }],
          web_path: [{ project: { namespace: [:route] } }],
          tags: [:tags]
        }
      end
    end
  end
end
