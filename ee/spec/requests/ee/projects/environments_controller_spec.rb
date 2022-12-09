# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::EnvironmentsController, feature_category: :projects do
  let_it_be_with_refind(:project) { create(:project, :repository) }

  let(:environment) { create(:environment, name: 'production', project: project) }

  describe 'GET #show' do
    subject { get project_environment_path(project, environment) }

    before do
      sign_in(project.owner)
      stub_licensed_features(protected_environments: true)

      create(:protected_environment, project: project, name: environment.name) do |protected_environment|
        create(:protected_environment_approval_rule, :maintainer_access, protected_environment: protected_environment)
        create(:protected_environment_approval_rule,
               user: create(:user), protected_environment: protected_environment)
        create(:protected_environment_approval_rule,
               group: create(:group), protected_environment: protected_environment)
      end
    end

    include_examples 'avoids N+1 queries on environment detail page'
  end

  def environment_params(opts = {})
    opts.reverse_merge(namespace_id: project.namespace,
                       project_id: project,
                       id: environment.id)
  end

  def create_deployment_with_associations(commit_depth:)
    commit = project.commit("HEAD~#{commit_depth}")
    create(:user, email: commit.author_email) unless User.find_by(email: commit.author_email)

    deployer = create(:user)
    pipeline = create(:ci_pipeline, project: environment.project)
    build = create(:ci_build, environment: environment.name, pipeline: pipeline, user: deployer)
    create(:deployment, :blocked, environment: environment, deployable: build, user: deployer,
                                  project: project, sha: commit.sha) do |deployment|
      create_list(:deployment_approval, 2, deployment: deployment)
    end
  end
end
