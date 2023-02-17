# frozen_string_literal: true

class AddFkIndexToCiBuildTraceMetadataOnPartitionIdAndBuildId < Gitlab::Database::Migration[2.1]
  disable_ddl_transaction!

  INDEX_NAME = :index_ci_build_trace_metadata_on_partition_id_build_id
  TABLE_NAME = :ci_build_trace_metadata
  COLUMNS = [:partition_id, :build_id]

  def up
    add_concurrent_index(TABLE_NAME, COLUMNS, name: INDEX_NAME, unique: true)
  end

  def down
    remove_concurrent_index_by_name(TABLE_NAME, INDEX_NAME)
  end
end
