# frozen_string_literal: true

module MergeRequests
  class ProcessApprovalAutoMergeWorker
    include Gitlab::EventStore::Subscriber

    data_consistency :always
    feature_category :continuous_delivery
    idempotent!

    def handle_event(event)
      merge_request_id = event.data[:merge_request_id]
      merge_request = MergeRequest.find_by_id(merge_request_id)

      unless merge_request
        logger.info(structured_payload(message: 'Merge request not found.', merge_request_id: merge_request_id))
        return
      end

      return unless Feature.enabled?(:merge_when_checks_pass, merge_request.project)

      AutoMergeService.new(merge_request.project, merge_request.merge_user)
                      .process(merge_request)
    end
  end
end
