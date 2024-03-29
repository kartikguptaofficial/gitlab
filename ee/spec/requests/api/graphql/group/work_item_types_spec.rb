# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'getting a list of work item types for a group EE', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:developer) { create(:user).tap { |u| group.add_developer(u) } }

  it_behaves_like 'graphql work item type list request spec', 'with work item types request context EE' do
    let(:current_user) { developer }
    let(:parent_key) { :group }

    let(:query) do
      graphql_query_for(
        'group',
        { 'fullPath' => group.full_path },
        query_nodes('WorkItemTypes', work_item_type_fields)
      )
    end
  end
end
