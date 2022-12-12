# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update of user activity', feature_category: :users do
  paths_to_visit = [
    '/group/project/-/integrations/jira/issues'
  ]

  it_behaves_like 'updating of user activity', paths_to_visit
end
