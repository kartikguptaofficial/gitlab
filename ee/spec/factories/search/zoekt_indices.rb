# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_index, class: '::Search::Zoekt::Index' do
    zoekt_enabled_namespace { association(:zoekt_enabled_namespace) }
    node { association(:zoekt_node) }
    namespace_id { zoekt_enabled_namespace.root_namespace_id }
  end
end
