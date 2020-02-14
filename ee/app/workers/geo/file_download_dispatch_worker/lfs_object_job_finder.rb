# frozen_string_literal: true

module Geo
  class FileDownloadDispatchWorker
    class LfsObjectJobFinder < JobFinder
      RESOURCE_ID_KEY = :lfs_object_id
      EXCEPT_RESOURCE_IDS_KEY = :except_ids
      FILE_SERVICE_OBJECT_TYPE = :lfs

      def registry_finder
        @registry_finder ||= Geo::LfsObjectRegistryFinder.new(current_node_id: Gitlab::Geo.current_node.id)
      end

      def find_unsynced_jobs(batch_size:)
        if Feature.enabled?(:geo_lfs_registry_ssot_sync)
          convert_registry_relation_to_job_args(
            registry_finder.find_never_synced_registries(find_batch_params(batch_size))
          )
        else
          super
        end
      end
    end
  end
end
