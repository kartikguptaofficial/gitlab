# frozen_string_literal: true

module Gitlab
  module Usage
    module Metrics
      module Instrumentations
        class CertBasedClustersFfMetric < GenericMetric
          value do
            Feature.enabled?(:certificate_based_clusters, default_enabled: :yaml, type: :ops)
          end
        end
      end
    end
  end
end
