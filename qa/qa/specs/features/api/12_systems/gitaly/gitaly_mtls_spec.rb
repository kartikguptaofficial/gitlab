# frozen_string_literal: true

module QA
  RSpec.describe 'Systems' do
    describe 'Gitaly using mTLS', :orchestrated, :mtls, product_group: :gitaly do
      let(:intial_commit_message) { 'Initial commit' }
      let(:first_added_commit_message) { 'commit over git' }
      let(:second_added_commit_message) { 'commit over api' }

      it 'pushes to gitaly', testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347677' do
        project = Resource::Project.fabricate! do |project|
          project.name = "mTLS"
          project.initialize_with_readme = true
        end

        # Debugging what branches are present
        # See https://gitlab.com/gitlab-org/gitlab/-/issues/431474
        QA::Runtime::Logger.info("project.all_branches.body #{project.all_branches.body}")

        Resource::Repository::ProjectPush.fabricate! do |push|
          push.project = project
          push.new_branch = false
          push.commit_message = first_added_commit_message
          push.file_content = 'First commit'
        end

        create(:commit, project: project, commit_message: second_added_commit_message, actions: [
          { action: 'create', file_path: "file-#{SecureRandom.hex(8)}", content: 'Second commit' }
        ])

        expect(project.commits.map { |commit| commit[:message].chomp })
          .to include(intial_commit_message)
                .and include(first_added_commit_message)
                       .and include(second_added_commit_message)
      end
    end
  end
end
