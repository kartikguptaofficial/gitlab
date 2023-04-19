# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Jobs (JavaScript fixtures)' do
  include ApiHelpers
  include JavaScriptFixturesHelpers
  include GraphqlHelpers

  let(:namespace) { create(:namespace, name: 'frontend-fixtures') }
  let(:project) { create(:project, :repository, namespace: namespace, path: 'builds-project') }
  let(:user) { project.first_owner }
  let(:pipeline) { create(:ci_empty_pipeline, project: project, sha: project.commit.id) }

  after do
    remove_repository(project)
  end

  describe Projects::JobsController, type: :controller do
    let!(:delayed) { create(:ci_build, :scheduled, pipeline: pipeline, name: 'delayed job') }

    before do
      sign_in(user)
    end

    it 'jobs/delayed.json' do
      get :show, params: {
        namespace_id: project.namespace.to_param,
        project_id: project,
        id: delayed.to_param
      }, format: :json

      expect(response).to be_successful
    end
  end

  describe GraphQL::Query, type: :request do
    let(:artifact) { create(:ci_job_artifact, file_type: :archive, file_format: :zip) }

    let!(:build) { create(:ci_build, :success, name: 'build', pipeline: pipeline) }
    let!(:cancelable) { create(:ci_build, :cancelable, name: 'cancelable', pipeline: pipeline) }
    let!(:failed) { create(:ci_build, :failed, name: 'failed', pipeline: pipeline) }
    let!(:created_by_tag) { create(:ci_build, :success, name: 'created_by_tag', tag: true, pipeline: pipeline) }
    let!(:pending) { create(:ci_build, :pending, name: 'pending', pipeline: pipeline) }
    let!(:playable) { create(:ci_build, :playable, name: 'playable', pipeline: pipeline) }
    let!(:retryable) { create(:ci_build, :retryable, name: 'retryable', pipeline: pipeline) }
    let!(:scheduled) { create(:ci_build, :scheduled, name: 'scheduled', pipeline: pipeline) }
    let!(:with_artifact) { create(:ci_build, :success, name: 'with_artifact', job_artifacts: [artifact], pipeline: pipeline) }
    let!(:with_coverage) { create(:ci_build, :success, name: 'with_coverage', coverage: 40.0, pipeline: pipeline) }

    shared_examples 'graphql queries' do |path, jobs_query|
      let_it_be(:variables) { {} }

      let_it_be(:query) do
        get_graphql_query_as_string("#{path}/#{jobs_query}")
      end

      fixtures_path = 'graphql/jobs/'

      it "#{fixtures_path}#{jobs_query}.json" do
        post_graphql(query, current_user: user, variables: variables)

        expect_graphql_errors_to_be_empty
      end

      it "#{fixtures_path}#{jobs_query}.as_guest.json" do
        guest = create(:user)
        project.add_guest(guest)

        post_graphql(query, current_user: guest, variables: variables)

        expect_graphql_errors_to_be_empty
      end

      it "#{fixtures_path}#{jobs_query}.paginated.json" do
        post_graphql(query, current_user: user, variables: variables.merge({ first: 2 }))

        expect_graphql_errors_to_be_empty
      end

      it "#{fixtures_path}#{jobs_query}.empty.json" do
        post_graphql(query, current_user: user, variables: variables.merge({ first: 0 }))

        expect_graphql_errors_to_be_empty
      end
    end

    it_behaves_like 'graphql queries', 'jobs/components/table/graphql/queries', 'get_jobs.query.graphql' do
      let(:variables) { { fullPath: 'frontend-fixtures/builds-project' } }
    end

    it_behaves_like 'graphql queries', 'pages/admin/jobs/components/table/graphql/queries', 'get_all_jobs.query.graphql' do
      let(:user) { create(:admin) }
    end
  end

  describe 'get_jobs_count.query.graphql', type: :request do
    let!(:build) { create(:ci_build, :success, name: 'build', pipeline: pipeline) }
    let!(:cancelable) { create(:ci_build, :cancelable, name: 'cancelable', pipeline: pipeline) }
    let!(:failed) { create(:ci_build, :failed, name: 'failed', pipeline: pipeline) }

    fixtures_path = 'graphql/jobs/'
    get_jobs_count_query = 'get_jobs_count.query.graphql'
    full_path = 'frontend-fixtures/builds-project'

    let_it_be(:query) do
      get_graphql_query_as_string("jobs/components/table/graphql/queries/#{get_jobs_count_query}")
    end

    it "#{fixtures_path}#{get_jobs_count_query}.json" do
      post_graphql(query, current_user: user, variables: {
        fullPath: full_path
      })

      expect_graphql_errors_to_be_empty
    end
  end
end
