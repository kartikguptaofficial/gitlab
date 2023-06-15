# frozen_string_literal: true

class ReplacePCiRunnerMachineBuildsForeignKeyV3 < Gitlab::Database::Migration[2.1]
  include Gitlab::Database::PartitioningMigrationHelpers
  include Gitlab::Database::MigrationHelpers::WraparoundAutovacuum

  disable_ddl_transaction!

  def up
    return unless should_run?

    add_concurrent_partitioned_foreign_key :p_ci_runner_machine_builds, :p_ci_builds,
      name: :temp_fk_bb490f12fe_p,
      column: [:partition_id, :build_id],
      target_column: [:partition_id, :id],
      on_update: :cascade,
      on_delete: :cascade,
      validate: true,
      reverse_lock_order: true
  end

  def down
    return unless should_run?

    with_lock_retries do
      remove_foreign_key_if_exists :p_ci_runner_machine_builds, :p_ci_builds,
        name: :temp_fk_bb490f12fe_p,
        reverse_lock_order: true
    end
  end

  private

  def should_run?
    can_execute_on?(:ci_builds)
  end
end
