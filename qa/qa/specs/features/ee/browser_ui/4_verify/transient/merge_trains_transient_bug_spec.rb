# frozen_string_literal: true

module QA
  RSpec.describe 'Verify', :runner, :transient, product_group: :pipeline_execution do
    describe 'Merge trains transient bugs' do
      let(:group) { create(:group) }

      let!(:runner) do
        create(:group_runner, group: group, name: group.name, tags: [group.name])
      end

      let(:project) { create(:project, name: 'merge-trains-transient-bugs', group: group) }

      let!(:ci_file) do
        create(:commit, project: project, commit_message: 'Add .gitlab-ci.yml', actions: [
          {
            action: 'create',
            file_path: '.gitlab-ci.yml',
            content: <<~YAML
              test:
                tags: [#{group.name}]
                script: echo 'OK'
                only:
                - merge_requests
            YAML
          }
        ])
      end

      before do
        Flow::Login.sign_in
        project.visit!
        Flow::MergeRequest.enable_merge_trains
      end

      after do
        runner.remove_via_api! if runner
        project.remove_via_api!
        group.remove_via_api!
      end

      it 'confirms that a merge train consistently completes and updates the UI', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348019' do
        Runtime::Env.transient_trials.times do |i|
          QA::Runtime::Logger.info("Transient bug test action - Trial #{i}")

          title = "merge train transient bug test #{random_string_for_this_trial}"

          # Create a merge request to be merged to master
          merge_request = create(:merge_request,
            title: title,
            project: project,
            description: title,
            target_new_branch: false,
            file_name: random_string_for_this_trial,
            file_content: random_string_for_this_trial)

          merge_request.visit!

          Page::MergeRequest::Show.perform do |show|
            # Wait for MR first pipeline to pass first before starting merge trains
            show.has_pipeline_status?('passed')
            show.merge_via_merge_train

            # This is also tested in pipelines_for_merged_results_and_merge_trains_spec.rb as a regular e2e test.
            show.wait_until(sleep_interval: 5, reload: false) do
              show.has_content?('started a merge train')
            end

            # Merge train should start another pipeline and MR won't merged until this is finished
            show.has_pipeline_status?('passed')

            # We use the API to wait until the MR has been merged so that we know the UI should be ready to update
            show.wait_until(reload: false) do
              merge_request_state(merge_request) == 'merged'
            end

            expect(show).to be_merged, "Expected content 'The changes were merged' but it did not appear."
          end
        end
      end

      private

      def random_string_for_this_trial
        SecureRandom.hex(8)
      end

      def merge_request_state(merge_request)
        create(:merge_request, project: project, iid: merge_request.iid).state
      end
    end
  end
end
