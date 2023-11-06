# frozen_string_literal: true

module Llm
  class GenerateDescriptionService < BaseService
    extend ::Gitlab::Utils::Override
    SUPPORTED_ISSUABLE_TYPES = %w[issue work_item].freeze

    override :valid
    def valid?
      super && Ability.allowed?(user, :generate_description, resource)
    end

    private

    def ai_action
      if Feature.enabled?(:claude_description_generation)
        :generate_description
      else
        :generate_description_open_ai
      end
    end

    def perform
      schedule_completion_worker
    end
  end
end
