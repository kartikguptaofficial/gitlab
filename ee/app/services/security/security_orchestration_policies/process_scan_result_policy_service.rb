# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ProcessScanResultPolicyService
      REPORT_TYPE_MAPPING = {
        Security::ScanResultPolicy::LICENSE_FINDING => :license_scanning,
        Security::ScanResultPolicy::ANY_MERGE_REQUEST => :any_merge_request
      }.freeze

      def initialize(project:, policy_configuration:, policy:, policy_index:)
        @policy_configuration = policy_configuration
        @policy = policy
        @policy_index = policy_index
        @project = project
        @author = policy_configuration.policy_last_updated_by
      end

      def execute
        create_new_approval_rules
      end

      private

      attr_reader :policy_configuration, :policy, :project, :author, :policy_index

      def create_new_approval_rules
        action_info = policy[:actions]&.find { |action| action[:type] == Security::ScanResultPolicy::REQUIRE_APPROVAL }

        policy[:rules]&.first(Security::ScanResultPolicy::LIMIT)&.each_with_index do |rule, rule_index|
          next unless rule_type_allowed?(rule[:type])

          scan_result_policy_read = create_scan_result_policy(
            rule, action_info, policy[:approval_settings], project, rule_index
          )

          create_software_license_policies(rule, rule_index, scan_result_policy_read) if license_finding?(rule)

          next unless create_approval_rule?(rule)

          ::ApprovalRules::CreateService
            .new(project, author, rule_params(rule, rule_index, action_info, scan_result_policy_read))
            .execute
        end
      end

      def create_approval_rule?(rule)
        return true if rule[:type] != Security::ScanResultPolicy::ANY_MERGE_REQUEST

        # For `any_merge_request` rules, the approval rules can be created without approvers and can override
        # project approval settings in general.
        # The violations in this case are handled via SyncAnyMergeRequestRulesService
        Feature.enabled?(:scan_result_any_merge_request, project) && policy[:actions].present?
      end

      def license_finding?(rule)
        rule[:type] == Security::ScanResultPolicy::LICENSE_FINDING
      end

      def create_software_license_policies(rule, _rule_index, scan_result_policy_read)
        rule[:license_types].each do |license_type|
          create_params = {
            name: license_type,
            approval_status: rule[:match_on_inclusion] ? 'denied' : 'allowed',
            scan_result_policy_read: scan_result_policy_read
          }

          ::SoftwareLicensePolicies::CreateService
            .new(project, author, create_params)
            .execute(is_scan_result_policy: true)
        end
      end

      def create_scan_result_policy(rule, action_info, project_approval_settings, project, rule_index)
        policy_configuration.scan_result_policy_reads.create!(
          orchestration_policy_idx: policy_index,
          rule_idx: rule_index,
          license_states: rule[:license_states],
          match_on_inclusion: rule[:match_on_inclusion] || false,
          role_approvers: role_access_levels(action_info&.dig(:role_approvers)),
          vulnerability_attributes: rule[:vulnerability_attributes],
          project_id: project.id,
          age_operator: rule.dig(:vulnerability_age, :operator),
          age_interval: rule.dig(:vulnerability_age, :interval),
          age_value: rule.dig(:vulnerability_age, :value),
          commits: rule[:commits],
          project_approval_settings: project_approval_settings || {}
        )
      end

      def rule_params(rule, rule_index, action_info, scan_result_policy_read)
        rule_params = {
          skip_authorization: true,
          approvals_required: action_info&.dig(:approvals_required) || 0,
          name: rule_name(policy[:name], rule_index),
          protected_branch_ids: protected_branch_ids(rule),
          applies_to_all_protected_branches: applies_to_all_protected_branches?(rule),
          rule_type: :report_approver,
          user_ids: users_ids(action_info&.dig(:user_approvers_ids), action_info&.dig(:user_approvers)),
          report_type: report_type(rule[:type]),
          orchestration_policy_idx: policy_index,
          group_ids: groups_ids(action_info&.dig(:group_approvers_ids), action_info&.dig(:group_approvers)),
          security_orchestration_policy_configuration_id: policy_configuration.id,
          scan_result_policy_id: scan_result_policy_read&.id,
          permit_inaccessible_groups: true
        }

        rule_params[:severity_levels] = [] if rule[:type] == Security::ScanResultPolicy::LICENSE_FINDING

        if rule[:type] == Security::ScanResultPolicy::SCAN_FINDING
          rule_params.merge!({
            scanners: rule[:scanners],
            severity_levels: rule[:severity_levels],
            vulnerabilities_allowed: rule[:vulnerabilities_allowed],
            vulnerability_states: rule[:vulnerability_states]
          })
        end

        rule_params
      end

      def protected_branch_ids(rule)
        service = Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project)
        applicable_branches = service.scan_result_branches([rule])
        protected_branches = project.all_protected_branches.select do |protected_branch|
          applicable_branches.any? { |branch| protected_branch.matches?(branch) }
        end

        protected_branches.pluck(:id) # rubocop: disable CodeReuse/ActiveRecord
      end

      def applies_to_all_protected_branches?(rule)
        rule[:branches] == [] || (rule[:branch_type] == "protected" && rule[:branch_exceptions].blank?)
      end

      def rule_type_allowed?(rule_type)
        [
          Security::ScanResultPolicy::SCAN_FINDING,
          Security::ScanResultPolicy::LICENSE_FINDING,
          Security::ScanResultPolicy::ANY_MERGE_REQUEST
        ].include?(rule_type)
      end

      def report_type(rule_type)
        REPORT_TYPE_MAPPING.fetch(rule_type, :scan_finding)
      end

      def rule_name(policy_name, rule_index)
        return policy_name if rule_index == 0

        "#{policy_name} #{rule_index + 1}"
      end

      def users_ids(user_ids, user_names)
        project.team.users.get_ids_by_ids_or_usernames(user_ids, user_names)
      end

      # rubocop: disable Cop/GroupPublicOrVisibleToUser
      def groups_ids(group_ids, group_paths)
        Security::ApprovalGroupsFinder.new(group_ids: group_ids,
          group_paths: group_paths,
          user: author,
          container: project.namespace,
          search_globally: search_groups_globally?).execute(include_inaccessible: true)
      end
      # rubocop: enable Cop/GroupPublicOrVisibleToUser

      def role_access_levels(role_approvers)
        return [] unless role_approvers

        roles_map = Gitlab::Access.sym_options_with_owner
        role_approvers
          .filter_map { |role| roles_map[role.to_sym] if role.to_s.in?(Security::ScanResultPolicy::ALLOWED_ROLES) }
      end

      def search_groups_globally?
        Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled?
      end
    end
  end
end
