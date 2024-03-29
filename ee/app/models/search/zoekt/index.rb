# frozen_string_literal: true

module Search
  module Zoekt
    class Index < ApplicationRecord
      self.table_name = 'zoekt_indices'

      belongs_to :zoekt_enabled_namespace, inverse_of: :indices, class_name: '::Search::Zoekt::EnabledNamespace'
      belongs_to :node, foreign_key: :zoekt_node_id, inverse_of: :indices, class_name: '::Search::Zoekt::Node'

      validate :zoekt_enabled_root_namespace_matches_namespace_id

      after_commit :index, on: :create
      after_commit :delete_from_index, on: :destroy

      enum state: {
        pending: 0,
        initializing: 1,
        ready: 10
      }

      private

      def zoekt_enabled_root_namespace_matches_namespace_id
        return unless zoekt_enabled_namespace.present? && namespace_id.present?
        return if zoekt_enabled_namespace.root_namespace_id == namespace_id

        errors.add(:namespace_id, :invalid)
      end

      def index
        ::Search::Zoekt::NamespaceIndexerWorker.perform_async(zoekt_enabled_namespace.root_namespace_id, :index)
      end

      def delete_from_index
        ::Search::Zoekt::NamespaceIndexerWorker.perform_async(zoekt_enabled_namespace.root_namespace_id,
          :delete, zoekt_node_id)
      end
    end
  end
end
