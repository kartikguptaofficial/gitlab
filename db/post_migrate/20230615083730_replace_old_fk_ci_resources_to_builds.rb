# frozen_string_literal: true

class ReplaceOldFkCiResourcesToBuilds < Gitlab::Database::Migration[2.1]
  include Gitlab::Database::MigrationHelpers::WraparoundAutovacuum

  disable_ddl_transaction!

  def up
    return unless should_run?
    return if new_foreign_key_exists?

    with_lock_retries do
      remove_foreign_key_if_exists :ci_resources, :ci_builds,
        name: :fk_e169a8e3d5_p, reverse_lock_order: true

      rename_constraint :ci_resources, :temp_fk_e169a8e3d5_p, :fk_e169a8e3d5_p
    end
  end

  def down
    return unless should_run?
    return unless new_foreign_key_exists?

    add_concurrent_foreign_key :ci_resources, :ci_builds,
      name: :temp_fk_e169a8e3d5_p,
      column: [:partition_id, :build_id],
      target_column: [:partition_id, :id],
      on_update: :cascade,
      on_delete: :nullify,
      validate: true,
      reverse_lock_order: true

    switch_constraint_names :ci_resources, :fk_e169a8e3d5_p, :temp_fk_e169a8e3d5_p
  end

  private

  def should_run?
    can_execute_on?(:ci_resources, :ci_builds)
  end

  def new_foreign_key_exists?
    foreign_key_exists?(:ci_resources, :p_ci_builds, name: :fk_e169a8e3d5_p)
  end
end
