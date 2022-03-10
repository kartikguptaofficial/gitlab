# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Harbor::RepositoriesController do
  let_it_be(:group, reload: true) { create(:group) }
  let_it_be(:user) { create(:user) }

  shared_examples 'responds with 404 status' do
    it 'returns 404' do
      subject

      expect(response).to have_gitlab_http_status(:not_found)
    end
  end

  shared_examples 'responds with 200 status' do
    it 'renders the index template' do
      subject

      expect(response).to have_gitlab_http_status(:ok)
      expect(response).to render_template(:index)
    end
  end

  before do
    stub_feature_flags(harbor_registry_integration: true)
    group.add_reporter(user)
    login_as(user)
  end

  describe 'GET #index' do
    subject do
      get group_harbor_registries_path(group)
      response
    end

    context 'with harbor registry feature flag enabled' do
      it_behaves_like 'responds with 200 status'
    end

    context 'with harbor registry feature flag disabled' do
      before do
        stub_feature_flags(harbor_registry_integration: false)
      end

      it_behaves_like 'responds with 404 status'
    end
  end

  describe 'GET #show' do
    subject do
      get group_harbor_registry_path(group, 1)
      response
    end

    context 'with harbor registry feature flag enabled' do
      it_behaves_like 'responds with 200 status'
    end

    context 'with harbor registry feature flag disabled' do
      before do
        stub_feature_flags(harbor_registry_integration: false)
      end

      it_behaves_like 'responds with 404 status'
    end
  end
end
