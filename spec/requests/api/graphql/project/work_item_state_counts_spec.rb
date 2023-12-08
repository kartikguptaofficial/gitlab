# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting Work Item counts by state', feature_category: :portfolio_management do
  include GraphqlHelpers

  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:project) { create(:project, :repository, :private, group: group) }
  let_it_be(:work_item_opened1) { create(:work_item, project: project, title: 'Foo') }
  let_it_be(:work_item_opened2) { create(:work_item, project: project, author: current_user) }
  let_it_be(:work_item_closed) { create(:work_item, :closed, project: project, description: 'Bar') }

  let(:params) { {} }

  subject(:query_counts) { post_graphql(query, current_user: current_user) }

  context 'with work items count data' do
    let(:work_item_counts) { graphql_data.dig('project', 'workItemStateCounts') }

    context 'with project permissions' do
      before_all do
        group.add_developer(current_user)
      end

      it_behaves_like 'a working graphql query' do
        before do
          query_counts
        end
      end

      it 'returns the correct counts for each state' do
        query_counts

        expect(work_item_counts).to eq(
          'all' => 3,
          'opened' => 2,
          'closed' => 1
        )
      end

      context 'when other work items are present in the group' do
        it 'only returns counts for work items in the current project' do
          other_project = create(:project, :repository, group: group)
          create(:work_item, project: other_project)
          query_counts

          expect(work_item_counts).to eq(
            'all' => 3,
            'opened' => 2,
            'closed' => 1
          )
        end
      end

      context 'when filters are provided' do
        context 'when filtering by author username' do
          let(:params) { { 'authorUsername' => current_user.username } }

          it 'returns the correct counts for each status' do
            query_counts

            expect(work_item_counts).to eq(
              'all' => 1,
              'opened' => 1,
              'closed' => 0
            )
          end
        end

        context 'when searching in title' do
          let(:params) {  { search: 'Foo', in: [:TITLE] } }

          it 'returns the correct counts for each status' do
            query_counts

            expect(work_item_counts).to eq(
              'all' => 1,
              'opened' => 1,
              'closed' => 0
            )
          end
        end

        context 'when searching in description' do
          let(:params) { { search: 'Bar', in: [:DESCRIPTION] } }

          it 'returns the correct counts for each status' do
            query_counts

            expect(work_item_counts).to eq(
              'all' => 1,
              'opened' => 0,
              'closed' => 1
            )
          end
        end
      end
    end

    context 'without project permissions' do
      it 'does not return work item counts' do
        query_counts

        expect_graphql_errors_to_be_empty
        expect(work_item_counts).to be_nil
      end
    end
  end

  def query(args: params)
    fields = <<~QUERY
      #{all_graphql_fields_for('WorkItemStateCountsType'.classify)}
    QUERY

    graphql_query_for(
      'project',
      { 'fullPath' => project.full_path },
      query_graphql_field('workItemStateCounts', args, fields)
    )
  end
end
