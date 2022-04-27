# frozen_string_literal: true

module QA
  module Flow
    module MergeRequest
      module_function

      def enable_merge_trains
        Page::Project::Menu.perform(&:go_to_general_settings)
        Page::Project::Settings::Main.perform(&:expand_merge_requests_settings)
        Page::Project::Settings::MergeRequest.perform(&:enable_merge_train)
      end

      # Opens the form to create a new merge request.
      # It tries to use the "Create merge request" button that appears after
      # a commit is pushed, but if that button isn't available, it uses the
      # "New merge request" button on the page that lists merge requests.
      #
      # @param [String] source_branch the branch to be merged
      def create_new(source_branch:)
        if Page::Project::Show.perform(&:has_create_merge_request_button?)
          Page::Project::Show.perform(&:new_merge_request)
          return
        end

        Page::Project::Menu.perform(&:click_merge_requests)
        Page::MergeRequest::Index.perform(&:click_new_merge_request)
        Page::MergeRequest::New.perform do |merge_request|
          merge_request.select_source_branch(source_branch)
          merge_request.click_compare_branches_and_continue
        end
      end
    end
  end
end
