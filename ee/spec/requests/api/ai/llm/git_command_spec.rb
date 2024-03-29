# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Ai::Llm::GitCommand, :saas, feature_category: :source_code_management do
  let_it_be(:current_user) { create :user }

  let(:url) { '/ai/llm/git_command' }
  let(:input_params) { { prompt: 'list 10 commit titles' } }
  let(:make_request) { post api(url, current_user), params: input_params }

  before do
    stub_licensed_features(ai_git_command: true)
    stub_ee_application_setting(should_check_namespace_plan: true)
  end

  describe 'POST /ai/llm/git_command', :saas, :use_clean_rails_redis_caching do
    let_it_be(:group, refind: true) { create(:group_with_plan, plan: :ultimate_plan) }

    before_all do
      group.add_developer(current_user)
    end

    include_context 'with ai features enabled for group'

    it_behaves_like 'delegates AI request to Workhorse' do
      let(:header) do
        {
          'Authorization' => ['Bearer access token'],
          'Content-Type' => ['application/json'],
          'Accept' => ["application/json"],
          'Host' => ['host']
        }
      end

      let(:expected_params) do
        expected_content = <<~PROMPT
        Provide the appropriate git commands for: list 10 commit titles.

        Respond with git commands wrapped in separate ``` blocks.
        Provide explanation for each command in a separate block.

        ##
        Example:

        ```
        git log -10
        ```

        This command will list the last 10 commits in the current branch.
        PROMPT

        {
          'URL' => "https://host/v1/projects/c/locations/us-central1/publishers/google/models/codechat-bison:predict",
          'Header' => header,
          'Body' => {
            instances: [{
              messages: [{
                author: "content",
                content: expected_content
              }]
            }],
            parameters: {
              temperature: 0.2,
              maxOutputTokens: 2048,
              topK: 40,
              topP: 0.95
            }
          }.to_json
        }
      end

      before do
        stub_ee_application_setting(vertex_ai_host: 'host', vertex_ai_project: 'c')

        allow_next_instance_of(::Gitlab::Llm::VertexAi::Configuration) do |instance|
          allow(instance).to receive(:access_token).and_return('access token')
        end
      end
    end

    context 'when ai_global_switch is turned off' do
      before do
        stub_feature_flags(ai_global_switch: false)
      end

      it 'returns bad request' do
        make_request

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end

    context 'when the endpoint is called too many times' do
      it 'returns too many requests response' do
        expect(Gitlab::ApplicationRateLimiter).to(
          receive(:throttled?).with(:ai_action, scope: [current_user]).and_return(true)
        )

        make_request

        expect(response).to have_gitlab_http_status(:too_many_requests)
      end
    end
  end
end
