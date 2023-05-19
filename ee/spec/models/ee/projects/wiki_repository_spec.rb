# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::WikiRepository, feature_category: :geo_replication do
  describe 'associations' do
    it {
      is_expected
        .to have_one(:wiki_repository_state)
        .class_name('Geo::WikiRepositoryState')
        .inverse_of(:project_wiki_repository)
        .autosave(false)
    }
  end

  include_examples 'a replicable model with a separate table for verification state' do
    let(:verifiable_model_record) { build(:project_wiki_repository) }
    let(:unverifiable_model_record) { nil }
  end

  it_behaves_like 'a project has a custom repo', :project_wiki_repository
end
