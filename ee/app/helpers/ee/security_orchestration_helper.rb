# frozen_string_literal: true

module EE::SecurityOrchestrationHelper
  def can_update_security_orchestration_policy_project?(container)
    can?(current_user, :update_security_orchestration_policy_project, container)
  end

  def can_modify_security_policy?(container)
    can?(current_user, :modify_security_policy, container)
  end

  def assigned_policy_project(container)
    return unless container&.security_orchestration_policy_configuration

    orchestration_policy_configuration = container.security_orchestration_policy_configuration
    security_policy_management_project = orchestration_policy_configuration.security_policy_management_project

    {
      id: security_policy_management_project.to_global_id.to_s,
      name: security_policy_management_project.name,
      full_path: security_policy_management_project.full_path,
      branch: security_policy_management_project.default_branch_or_main
    }
  end

  def orchestration_policy_data(container, policy_type = nil, policy = nil, approvers = nil)
    return unless container

    disable_scan_policy_update = !can_modify_security_policy?(container)

    policy_data = {
      assigned_policy_project: assigned_policy_project(container).to_json,
      disable_scan_policy_update: disable_scan_policy_update.to_s,
      namespace_id: container.id,
      namespace_path: container.full_path,
      policies_path: security_policies_path(container),
      policy: policy&.to_json,
      policy_editor_empty_state_svg_path: image_path('illustrations/monitoring/unable_to_connect.svg'),
      policy_type: policy_type,
      role_approver_types: Security::ScanResultPolicy::ALLOWED_ROLES,
      scan_policy_documentation_path: help_page_path('user/application_security/policies/index'),
      scan_result_approvers: approvers&.to_json,
      software_licenses: SoftwareLicense.all_license_names,
      global_group_approvers_enabled: Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled.to_json,
      root_namespace_path: container.root_ancestor&.full_path,
      timezones: timezone_data(format: :full).to_json,
      max_active_scan_execution_policies_reached: max_active_scan_execution_policies_reached(container).to_s,
      max_active_scan_result_policies_reached: max_active_scan_result_policies_reached(container).to_s,
      max_scan_result_policies_allowed: Security::ScanResultPolicy::LIMIT,
      max_scan_execution_policies_allowed: Security::ScanExecutionPolicy::POLICY_LIMIT,
      security_policies_policy_scope_toggle_enabled: security_policies_policy_scope_toggle_enabled(container).to_s
    }

    if container.is_a?(::Project)
      policy_data.merge(
        create_agent_help_path: help_page_url('user/clusters/agent/install/index')
      )
    else
      policy_data
    end
  end

  def security_policies_policy_scope_toggle_enabled(container)
    if container.is_a?(::Project)
      return false unless container.group

      container.group.namespace_settings.toggle_security_policies_policy_scope?
    else
      container.namespace_settings.toggle_security_policies_policy_scope?
    end
  end

  def security_policies_path(container)
    container.is_a?(::Project) ? project_security_policies_path(container) : group_security_policies_path(container)
  end

  def max_active_scan_execution_policies_reached(container)
    active_scan_execution_policy_count(container) >= Security::ScanExecutionPolicy::POLICY_LIMIT
  end

  def active_scan_execution_policy_count(container)
    container
      &.security_orchestration_policy_configuration
      &.active_scan_execution_policies
      &.length || 0
  end

  def max_active_scan_result_policies_reached(container)
    active_scan_result_policy_count(container) >= Security::ScanResultPolicy::LIMIT
  end

  def active_scan_result_policy_count(container)
    container
      &.security_orchestration_policy_configuration
      &.active_scan_result_policies
      &.length || 0
  end
end
