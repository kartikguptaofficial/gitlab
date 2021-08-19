# frozen_string_literal: true

module Projects::Security::PoliciesHelper
  def assigned_policy_project(project)
    return unless project&.security_orchestration_policy_configuration

    orchestration_policy_configuration = project.security_orchestration_policy_configuration
    security_policy_management_project = orchestration_policy_configuration.security_policy_management_project

    {
      id: security_policy_management_project.to_global_id.to_s,
      name: security_policy_management_project.name,
      full_path: security_policy_management_project.full_path,
      branch: security_policy_management_project.default_branch_or_main
    }
  end

  def orchestration_policy_data(project, policy_type = nil, policy = nil, environment = nil)
    return unless project

    disable_scan_execution_update = !can_update_security_orchestration_policy_project?(project)

    {
      assigned_policy_project: assigned_policy_project(project).to_json,
      disable_scan_execution_update: disable_scan_execution_update.to_s,
      network_policies_endpoint: project_security_network_policies_path(project),
      configure_agent_help_path: help_page_url('user/clusters/agent/repository.html'),
      create_agent_help_path: help_page_url('user/clusters/agent/index.md', anchor: 'create-an-agent-record-in-gitlab'),
      environments_endpoint: project_environments_path(project),
      environment_id: environment&.id,
      network_documentation_path: help_page_path('user/application_security/threat_monitoring/index.md'),
      no_environment_svg_path: image_path('illustrations/monitoring/unable_to_connect.svg'),
      policy: policy&.to_json,
      policy_type: policy_type,
      project_path: project.full_path,
      project_id: project.id,
      threat_monitoring_path: project_security_policies_path(project)
    }
  end
end
