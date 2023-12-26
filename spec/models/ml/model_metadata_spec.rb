# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ml::ModelMetadata, feature_category: :mlops do
  describe 'associations' do
    it { is_expected.to belong_to(:model).required }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:value).is_at_most(5000) }
  end

  describe 'validations' do
    let_it_be(:metadata) { create(:ml_model_metadata, name: 'some_metadata') }
    let_it_be(:model) { metadata.model }

    it 'is unique within the model' do
      expect do
        model.metadata.create!(name: 'some_metadata', value: 'blah')
      end.to raise_error.with_message(/Name 'some_metadata' already taken/)
    end

    it 'a model is required' do
      expect do
        described_class.create!(name: 'some_metadata', value: 'blah')
      end.to raise_error.with_message(/Model must exist/)
    end
  end
end
