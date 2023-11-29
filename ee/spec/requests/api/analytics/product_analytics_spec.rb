# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Analytics::ProductAnalytics, feature_category: :product_analytics_data_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :with_product_analytics_funnel, group: group) }

  let(:current_user) { create(:user) }

  shared_examples_for 'well behaved cube query' do |options = { stub_service: true }|
    before do
      stub_cube_proxy_setup
    end

    context 'when current user has guest project access' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_guest(current_user)
        stub_cube_data_service_unauthorized if options[:stub_service]
      end

      it 'returns an unauthorized error' do
        request

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when current user is a project developer' do
      let_it_be(:current_user) { create(:user) }

      before do
        project.add_developer(current_user)
        stub_cube_data_service_success if options[:stub_service]
      end

      it 'returns a 200' do
        request

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end

  describe 'GET projects/:id/product_analytics/request/load' do
    let(:request) do
      post api("/projects/#{project.id}/product_analytics/request/load", current_user),
               params: { query: { measures: ['TrackedEvents.count'] }, 'queryType': 'multi' }
    end

    it_behaves_like 'well behaved cube query'
  end

  describe 'GET projects/:id/product_analytics/request/dry-run' do
    let(:request) do
      post api("/projects/#{project.id}/product_analytics/request/dry-run", current_user),
           params: { query: { measures: ['TrackedEvents.count'] }, 'queryType': 'multi' }
    end

    it_behaves_like 'well behaved cube query'
  end

  describe 'GET projects/:id/product_analytics/meta' do
    let(:request) { post api("/projects/#{project.id}/product_analytics/request/meta", current_user) }

    it_behaves_like 'well behaved cube query'
  end

  describe 'GET projects/:id/product_analytics/funnels' do
    let(:request) { get api("/projects/#{project.id}/product_analytics/funnels", current_user) }

    context 'when project is not moved' do
      before do
        stub_cube_product_analytics_enabled
      end

      it_behaves_like 'well behaved cube query', { sub_service: false }
    end

    context 'when a project is moved' do
      let_it_be(:redirect_route) { 'new/project/location' }

      it 'returns 404 error' do
        project.route.create_redirect(redirect_route)

        get api("/projects/#{CGI.escape(redirect_route)}/product_analytics/funnels", current_user)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end

  private

  def stub_cube_proxy_setup
    stub_licensed_features(product_analytics: true, experimental_features: true)
    stub_ee_application_setting(product_analytics_enabled: true)
    stub_ee_application_setting(cube_api_key: 'testtest')
    stub_ee_application_setting(cube_api_base_url: 'http://cube.dev')
    allow(project.group.root_ancestor.namespace_settings).to receive(:experiment_settings_allowed?).and_return(true)
    project.group.root_ancestor.namespace_settings.update!(
      experiment_features_enabled: true,
      product_analytics_enabled: true
    )
  end

  def stub_cube_product_analytics_enabled
    expect_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |service|
      expect(service).to receive(:product_analytics_enabled?).and_return(true)
    end
  end

  def stub_cube_data_service_success
    expect_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |service|
      expect(service).to receive(:execute).and_return(ServiceResponse.success(message: 'test success'))
    end
  end

  def stub_cube_data_service_unauthorized
    expect_next_instance_of(::ProductAnalytics::CubeDataQueryService) do |service|
      expect(service).to receive(:execute).and_return(
        ServiceResponse.error(message: 'test unauthorized', reason: :unauthorized)
      )
    end
  end
end
