# frozen_string_literal: true

require 'spec_helper'
require 'mime/types'

RSpec.describe API::Ml::Mlflow do
  include SessionHelpers
  include ApiHelpers
  include HttpBasicAuthHelpers

  let(:user) { create(:user) }
  let(:developer) { create(:user).tap { |u| project.add_developer(u) } }
  let(:current_user) { developer }

  let(:project) do
    create(:project,
           :private,
           creator_id: user.id,
           namespace: user.namespace,
           path: 'my.project',
           id: 123454)
  end

  let(:ff_value) { true }

  let(:experiment) { create(:ml_experiments, name: 'the_experiment', user: user, project: project) }

  let(:scopes) { %w[api] }
  let(:headers) do
    { 'Authorization' => "Bearer #{create(:personal_access_token, scopes: scopes, user: current_user).token}" }
  end

  let(:params) { {} }
  let(:request) { get api(route), params: params, headers: headers }

  before do
    stub_feature_flags(ml_experiment_tracking: ff_value)

    create(:ml_experiments, name: 'existing_experiment', user: user, project: project)

    request
  end

  shared_examples 'Not Found' do |message|
    it "is Not Found" do
      expect(response).to have_gitlab_http_status(:not_found)

      expect(json_response['message']).to eq(message) if message.present?
    end
  end

  shared_examples 'Not Found - Resource Does Not Exist' do
    it "is Resource Does Not Exist" do
      expect(response).to have_gitlab_http_status(:not_found)

      expect(json_response).to include({ "error_code" => 'RESOURCE_DOES_NOT_EXIST' })
    end
  end

  shared_examples 'Bad Request' do |error_code = nil|
    it "is Bad Request" do
      expect(response).to have_gitlab_http_status(:bad_request)

      expect(json_response).to include({ 'error_code' => error_code }) if error_code.present?
    end
  end

  shared_examples 'shared error cases' do
    context 'when not authenticated' do
      let(:headers) { {} }

      it "is Unauthorized" do
        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when user does not have access' do
      let(:current_user) { create(:user) }

      it_behaves_like 'Not Found'
    end

    context 'when ff is disabled' do
      let(:ff_value) { false }

      it_behaves_like 'Not Found'
    end
  end

  describe 'GET /projects/:id/ml/mflow/api/2.0/mlflow/get' do
    let(:route) { "/projects/#{project.id}/ml/mflow/api/2.0/mlflow/experiments/get?experiment_id=#{experiment_id}" }
    let(:experiment_id) { experiment.iid.to_s }

    it 'returns the experiment' do
      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('ml/get_experiment')
      expect(json_response).to include({
                                         'experiment' => {
                                           'experiment_id' => '2',
                                           'name' => 'the_experiment',
                                           'lifecycle_stage' => 'active',
                                           'artifact_location' => 'not_implemented'
                                         }
                                       })
    end

    describe 'Error States' do
      context 'when has access' do
        context 'and experiment does not exist' do
          let(:experiment_id) { '2' }

          it_behaves_like 'Not Found - Resource Does Not Exist'
        end

        context 'and experiment_id is not passed' do
          let(:route) { "/projects/#{project.id}/ml/mflow/api/2.0/mlflow/experiments/get" }

          it_behaves_like 'Not Found - Resource Does Not Exist'
        end
      end

      it_behaves_like 'shared error cases'
    end
  end

  describe 'GET /projects/:id/ml/mflow/api/2.0/mlflow/experiments/get-by-name' do
    let(:route) do
      "/projects/#{project.id}/ml/mflow/api/2.0/mlflow/experiments/get-by-name?experiment_name=#{experiment_name}"
    end

    let(:experiment_name) { experiment.name }

    it 'returns the experiment' do
      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to match_response_schema('ml/get_experiment')
      expect(json_response).to include({
                                         'experiment' => {
                                           'experiment_id' => '2',
                                           'name' => 'the_experiment',
                                           'lifecycle_stage' => 'active',
                                           'artifact_location' => 'not_implemented'
                                         }
                                       })
    end

    describe 'Error States' do
      context 'when has access but experiment does not exist' do
        let(:experiment_name) { "random_experiment" }

        it_behaves_like 'Not Found - Resource Does Not Exist'
      end

      context 'when has access but experiment_name is not passed' do
        let(:route) { "/projects/#{project.id}/ml/mflow/api/2.0/mlflow/experiments/get-by-name" }

        it_behaves_like 'Not Found - Resource Does Not Exist'
      end

      it_behaves_like 'shared error cases'
    end
  end

  describe 'POST /projects/:id/ml/mflow/api/2.0/mlflow/experiments/create' do
    let(:route) do
      "/projects/#{project.id}/ml/mflow/api/2.0/mlflow/experiments/create"
    end

    let(:params) { { name: 'new_experiment' } }
    let(:request) { post api(route), params: params, headers: headers }

    it 'creates the experiment' do
      expect(response).to have_gitlab_http_status(:created)
      expect(json_response).to include({ 'experiment_id' => '2' })
    end

    describe 'Error States' do
      context 'when experiment name is not passed' do
        let(:params) { {} }

        it_behaves_like 'Bad Request'
      end

      context 'when experiment name already exists' do
        let(:params) { { name: 'existing_experiment' } }

        it_behaves_like 'Bad Request', 'RESOURCE_ALREADY_EXISTS'
      end

      context 'when project does not exist' do
        let(:route) { "/projects/9999999/ml/mflow/api/2.0/mlflow/experiments/create" }

        it_behaves_like 'Not Found', '404 Project Not Found'
      end
    end
  end
end
