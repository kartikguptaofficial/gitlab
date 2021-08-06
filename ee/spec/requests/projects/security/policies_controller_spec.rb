# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Security::PoliciesController, type: :request do
  let_it_be(:owner) { create(:user) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, namespace: owner.namespace) }
  let_it_be(:policy_management_project) { create(:project, :repository, namespace: owner.namespace) }
  let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration, security_policy_management_project: policy_management_project, project: project) }
  let_it_be(:policy) do
    {
      name: 'Run DAST in every pipeline',
      description: 'This policy enforces to run DAST for every pipeline within the project',
      enabled: true,
      rules: [{ type: 'pipeline', branches: %w[production] }],
      actions: [
        { scan: 'dast', site_profile: 'Site Profile', scanner_profile: 'Scanner Profile' }
      ]
    }
  end

  let_it_be(:type) { 'scan_execution_policy' }
  let_it_be(:show) { project_security_policy_url(project) }
  let_it_be(:edit) { edit_project_security_policy_url(project, id: policy[:name], type: type) }

  let_it_be(:feature_enabled) { true }

  before do
    project.add_developer(user)
    sign_in(user)
    stub_feature_flags(security_orchestration_policies_configuration: feature_enabled)
    stub_licensed_features(security_orchestration_policies: feature_enabled)
    allow_next_instance_of(Repository) do |repository|
      allow(repository).to receive(:blob_data_at).and_return({ scan_execution_policy: [policy] }.to_yaml)
    end
  end

  describe 'GET #edit' do
    context 'with authorized user' do
      context 'when feature is available' do
        it 'renders the edit page' do
          get edit

          expect(response).to have_gitlab_http_status(:ok)
          expect(response).to render_template(:edit)

          app = Nokogiri::HTML.parse(response.body).at_css('div#js-policy-builder-app')

          expect(app.attributes['data-policy'].value).to eq(policy.to_json)
          expect(app.attributes['data-policy-type'].value).to eq(type)
        end

        context 'when type is missing' do
          let_it_be(:edit) { edit_project_security_policy_url(project, id: policy[:name]) }

          it 'returns 404' do
            get edit

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when id does not exist' do
          let_it_be(:edit) { edit_project_security_policy_url(project, id: 'no-existing-policy', type: type) }

          it 'returns 404' do
            get edit

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end

        context 'when there is no policy configuration' do
          let_it_be(:project) { create(:project, namespace: owner.namespace) }
          let_it_be(:policy_configuration) { nil }
          let_it_be(:edit) { edit_project_security_policy_url(project, id: policy[:name], type: type) }

          it 'redirects to policy configuration page' do
            get edit

            expect(response).to redirect_to(project_security_policy_path(project))
          end
        end

        context 'when policy yaml file does not exist' do
          before do
            allow_next_instance_of(Repository) do |repository|
              allow(repository).to receive(:blob_data_at).and_return({}.to_yaml)
            end
          end

          it 'redirects to project page' do
            get edit

            expect(response).to redirect_to(project_path(policy_management_project))
          end
        end

        context 'when policy yaml is invalid' do
          let_it_be(:policy) { 'invalid' }

          it 'redirects to policy file' do
            get edit

            expect(response).to redirect_to(
              project_blob_path(
                policy_management_project,
                File.join(policy_management_project.default_branch, ::Security::OrchestrationPolicyConfiguration::POLICY_PATH)
              )
            )
          end
        end
      end

      context 'when feature is not available' do
        let_it_be(:feature_enabled) { false }

        it 'returns 404' do
          get edit

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'with unauthorized user' do
      before do
        project.add_guest(user)
        sign_in(user)
      end

      context 'when feature is available' do
        let_it_be(:feature_enabled) { true }

        it 'returns 404' do
          get edit

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    context 'with anonymous user' do
      before do
        sign_out(user)
      end

      it 'returns 302' do
        get edit

        expect(response).to have_gitlab_http_status(:found)
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #show' do
    using RSpec::Parameterized::TableSyntax

    where(:feature_flag, :license, :status) do
      true | true | :ok
      false | false | :not_found
      false | true | :not_found
      true | false | :not_found
    end

    subject(:request) { get show, params: { namespace_id: project.namespace, project_id: project } }

    with_them do
      before do
        stub_feature_flags(security_orchestration_policies_configuration: feature_flag)
        stub_licensed_features(security_orchestration_policies: license)
      end

      specify do
        subject

        expect(response).to have_gitlab_http_status(status)
      end
    end
  end
end
