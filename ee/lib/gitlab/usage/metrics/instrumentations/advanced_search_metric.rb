# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class AdvancedSearchMetric < GenericMetric
          fallback({})

          value do
            ::Gitlab::Elastic::Helper.default.server_info
          end
        end
      end
    end
  end
end
