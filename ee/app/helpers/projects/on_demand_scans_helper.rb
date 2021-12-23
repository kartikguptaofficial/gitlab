# frozen_string_literal: true

module Projects::OnDemandScansHelper
  # rubocop: disable CodeReuse/ActiveRecord
  def on_demand_scans_data(project)
    on_demand_scans = project.all_pipelines.where(source: Enums::Ci::Pipeline.sources[:ondemand_dast_scan])
    running_scans_count, finished_scans_count = count_running_and_finished_scans(on_demand_scans)
    saved_scans = ::Dast::ProfilesFinder.new({ project_id: project.id }).execute
    scheduled_scans_count = saved_scans.count { |scan| scan.dast_profile_schedule }

    common_data(project).merge({
      'project-on-demand-scan-counts-etag' => graphql_etag_project_on_demand_scan_counts_path(project),
      'on-demand-scan-counts' => {
        all: on_demand_scans.length,
        running: running_scans_count,
        finished: finished_scans_count,
        scheduled: scheduled_scans_count,
        saved: saved_scans.count
      }.to_json,
      'new-dast-scan-path' => new_project_on_demand_scan_path(project),
      'empty-state-svg-path' => image_path('illustrations/empty-state/ondemand-scan-empty.svg'),
      'timezones' => timezone_data(format: :abbr).to_json
    })
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def on_demand_scans_form_data(project)
    common_data(project).merge({
      'default-branch' => project.default_branch,
      'profiles-library-path' => project_security_configuration_dast_scans_path(project),
      'scanner-profiles-library-path' => project_security_configuration_dast_scans_path(project, anchor: 'scanner-profiles'),
      'site-profiles-library-path' => project_security_configuration_dast_scans_path(project, anchor: 'site-profiles'),
      'new-scanner-profile-path' => new_project_security_configuration_dast_scans_dast_scanner_profile_path(project),
      'new-site-profile-path' => new_project_security_configuration_dast_scans_dast_site_profile_path(project),
      'timezones' => timezone_data(format: :full).to_json
    })
  end

  private

  def common_data(project)
    {
      'project-path' => project.path_with_namespace
    }
  end

  def count_running_and_finished_scans(on_demand_scans)
    running_scans_count = 0
    finished_scans_count = 0

    on_demand_scans.each do |pipeline|
      if %w[success failed canceled].include?(pipeline.status)
        finished_scans_count += 1
      elsif pipeline.status == "running"
        running_scans_count += 1
      end
    end

    [running_scans_count, finished_scans_count]
  end
end
