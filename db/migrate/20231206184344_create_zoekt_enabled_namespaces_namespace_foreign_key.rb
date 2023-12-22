# frozen_string_literal: true

class CreateZoektEnabledNamespacesNamespaceForeignKey < Gitlab::Database::Migration[2.2]
  disable_ddl_transaction!
  milestone '16.8'

  def up
    add_concurrent_foreign_key :zoekt_enabled_namespaces, :namespaces, column: :root_namespace_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :zoekt_enabled_namespaces, column: :root_namespace_id
    end
  end
end
