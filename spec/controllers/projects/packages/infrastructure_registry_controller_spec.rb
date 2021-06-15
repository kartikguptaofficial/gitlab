# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::Packages::InfrastructureRegistryController do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :private) }

  let(:params) { { namespace_id: project.namespace, project_id: project } }

  before do
    sign_in(user)
    project.add_maintainer(user)
  end

  describe 'GET #index' do
    subject { get :index, params: params, format: :html }

    it_behaves_like 'returning response status', :ok

    context 'when the feature is disabled' do
      before do
        stub_feature_flags(infrastructure_registry_page: false)
      end

      it_behaves_like 'returning response status', :not_found
    end
  end

  describe 'GET #show' do
    let_it_be(:terraform_module) { create(:terraform_module_package, project: project) }

    subject { get :show, params: params.merge(id: terraform_module.id), format: :html }

    it_behaves_like 'returning response status', :ok

    context 'when the feature is disabled' do
      before do
        stub_feature_flags(infrastructure_registry_page: false)
      end

      it_behaves_like 'returning response status', :not_found
    end
  end
end
