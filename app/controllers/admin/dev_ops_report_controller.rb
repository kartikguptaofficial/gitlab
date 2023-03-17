# frozen_string_literal: true

class Admin::DevOpsReportController < Admin::ApplicationController
  include ProductAnalyticsTracking

  helper_method :show_adoption?

  track_event :show,
    name: 'i_analytics_dev_ops_score',
    action: 'perform_analytics_usage_action',
    label: 'redis_hll_counters.analytics.analytics_total_unique_counts_monthly',
    destinations: %i[redis_hll snowplow],
    conditions: -> { should_track_devops_score? }

  feature_category :devops_reports

  urgency :low

  # rubocop: disable CodeReuse/ActiveRecord
  def show
    @metric = DevOpsReport::Metric.order(:created_at).last&.present
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def show_adoption?
    false
  end

  def should_track_devops_score?
    true
  end

  def tracking_namespace_source
    nil
  end

  def tracking_project_source
    nil
  end
end

Admin::DevOpsReportController.prepend_mod_with('Admin::DevOpsReportController')
