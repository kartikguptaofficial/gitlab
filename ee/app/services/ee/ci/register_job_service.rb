# frozen_string_literal: true

module EE
  module Ci
    module RegisterJobService
      extend ::Gitlab::Utils::Override

      override :pre_assign_runner_checks
      def pre_assign_runner_checks
        super.merge({
          ip_restriction_failure: ->(build, _) { build.project.group && !::Gitlab::IpRestriction::Enforcer.new(build.project.group).allows_current_ip? }
        })
      end
    end
  end
end
