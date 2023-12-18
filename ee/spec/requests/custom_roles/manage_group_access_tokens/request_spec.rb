# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User with manage_group_access_tokens custom role', feature_category: :permissions do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }

  before do
    stub_licensed_features(custom_roles: true)
    sign_in(user)
  end

  describe Groups::Settings::AccessTokensController do
    let_it_be(:role) { create(:member_role, :guest, namespace: group, manage_group_access_tokens: true) }
    let_it_be(:member) { create(:group_member, :guest, member_role: role, user: user, group: group) }

    describe '#index' do
      it 'user has access via custom role' do
        get group_settings_access_tokens_path(group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response).to render_template(:index)
      end
    end

    describe '#create' do
      let_it_be(:access_token_params) { { name: 'TestToken', scopes: ['api'], expires_at: Date.today + 1.month } }
      let_it_be(:resource) { group }

      subject(:request) do
        post group_settings_access_tokens_path(group, params: { resource_access_token: access_token_params })
      end

      it 'user has access via a custom role' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end

      it_behaves_like 'POST resource access tokens available'
    end

    describe '#revoke' do
      let_it_be(:access_token_user) { create(:user, :project_bot) }
      let_it_be(:group_member) { create(:group_member, user: access_token_user, group: group) }
      let_it_be(:resource_access_token) { create(:personal_access_token, user: access_token_user) }

      subject(:request) { put revoke_group_settings_access_token_path(group, resource_access_token) }

      it 'user has access via a custom role' do
        request

        expect(resource_access_token.reload).to be_revoked
        expect(response).to have_gitlab_http_status(:redirect)
      end
    end

    describe GroupsController do
      it 'user has access via custom role' do
        get group_path(group)

        expect(response).to have_gitlab_http_status(:ok)
        expect(response.body).to include('Access Tokens')
      end
    end
  end
end
