# frozen_string_literal: true

module EE
  module Environment
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Utils::StrongMemoize

    prepended do
      has_many :prometheus_alerts, inverse_of: :environment
      has_one :last_deployable, through: :last_deployment, source: 'deployable', source_type: 'CommitStatus'
      has_one :last_pipeline, through: :last_deployable, source: 'pipeline'

      # Returns environments where its latest deployment is to a cluster
      scope :deployed_to_cluster, -> (cluster) do
        joins(:deployments)
          .joins("LEFT OUTER JOIN deployments AS later_deployments ON later_deployments.environment_id = deployments.environment_id AND deployments.id < later_deployments.id")
          .where("later_deployments.id IS NULL")
          .where(deployments: { cluster_id: cluster.id })
      end

      scope :preload_for_cluster_environment_entity, -> do
        preload(
          last_deployment: [:deployable],
          project: [:route, { namespace: :route }]
        )
      end
    end

    def reactive_cache_updated
      super

      ::Gitlab::EtagCaching::Store.new.tap do |store|
        store.touch(
          ::Gitlab::Routing.url_helpers.project_environments_path(project, format: :json))
      end
    end

    def pod_names
      return [] unless rollout_status

      rollout_status.instances.map do |instance|
        instance[:pod_name]
      end
    end

    def clear_prometheus_reactive_cache!(query_name)
      cluster_prometheus_adapter&.clear_prometheus_reactive_cache!(query_name, self)
    end

    def cluster_prometheus_adapter
      @cluster_prometheus_adapter ||= Prometheus::AdapterService.new(project, deployment_platform).cluster_prometheus_adapter
    end

    def protected?
      project.protected_environment_by_name(name).present?
    end

    def protected_deployable_by_user?(user)
      project.protected_environment_accessible_to?(name, user)
    end

    def rollout_status
      return unless has_terminals?

      result = with_reactive_cache do |data|
        deployment_platform.rollout_status(self, data)
      end

      result || ::Gitlab::Kubernetes::RolloutStatus.loading
    end
  end
end
