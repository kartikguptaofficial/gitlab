# frozen_string_literal: true

module EE
  module Gitlab
    module Observability
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      class_methods do
        def tracing_url(project)
          "#{::Gitlab::Observability.observability_url}/query/#{project.group.id}/#{project.id}/v1/traces"
        end
      end
    end
  end
end
