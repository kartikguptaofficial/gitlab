# frozen_string_literal: true

class PipelineMetricsWorker # rubocop:disable Scalability/IdempotentWorker
  include ApplicationWorker

  data_consistency :always

  sidekiq_options retry: 3
  include PipelineQueue

  urgency :low

  def perform(pipeline_id)
    Ci::Pipeline.find_by_id(pipeline_id).try do |pipeline|
      update_metrics_for_active_pipeline(pipeline) if pipeline.active?
      update_metrics_for_succeeded_pipeline(pipeline) if pipeline.success?
    end
  end

  private

  def update_metrics_for_active_pipeline(pipeline)
    metrics(pipeline).update_all(latest_build_started_at: pipeline.started_at, latest_build_finished_at: nil, pipeline_id: pipeline.id)
  end

  def update_metrics_for_succeeded_pipeline(pipeline)
    metrics(pipeline).update_all(latest_build_started_at: pipeline.started_at, latest_build_finished_at: pipeline.finished_at, pipeline_id: pipeline.id)
  end

  def metrics(pipeline)
    MergeRequest::Metrics.where(merge_request_id: merge_requests(pipeline)) # rubocop: disable CodeReuse/ActiveRecord
  end

  def merge_requests(pipeline)
    pipeline.merge_requests_as_head_pipeline.map(&:id)
  end
end
