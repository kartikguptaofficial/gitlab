# frozen_string_literal: true

class AddOrganizationIdForeignKeyToOrganizationUsers < Gitlab::Database::Migration[2.1]
  disable_ddl_transaction!

  def up
    add_concurrent_foreign_key :organization_users, :organizations, column: :organization_id, on_delete: :cascade
  end

  def down
    with_lock_retries do
      remove_foreign_key :organization_users, column: :organization_id
    end
  end
end
