# frozen_string_literal: true

module AuditEvents
  module Strategies
    class AmazonS3DestinationStrategy < BaseAmazonS3DestinationStrategy
      def streamable?
        group = audit_event.root_group_entity
        return false if group.nil?
        return false unless group.licensed_feature_available?(:external_audit_events)

        group.amazon_s3_configurations.exists?
      end

      private

      def destinations
        group = audit_event.root_group_entity
        group.present? ? group.amazon_s3_configurations.to_a : []
      end
    end
  end
end
