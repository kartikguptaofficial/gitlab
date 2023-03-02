# frozen_string_literal: true

module Projects
  module Settings
    module BranchRulesHelper
      def branch_rules_data(project)
        {
          project_path: project.full_path,
          protected_branches_path: project_settings_repository_path(project, anchor: 'js-protected-branches-settings'),
          approval_rules_path: project_settings_merge_requests_path(project,
            anchor: 'js-merge-request-approval-settings'),
          status_checks_path: project_settings_merge_requests_path(project, anchor: 'js-merge-request-settings'),
          branches_path: project_branches_path(project),
          show_status_checks: 'false',
          show_approvers: 'false',
          show_code_owners: 'false'
        }
      end
    end
  end
end

Projects::Settings::BranchRulesHelper.prepend_mod
