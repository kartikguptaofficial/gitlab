# frozen_string_literal: true

class AddIndexUsersOnUpdatedAt < Gitlab::Database::Migration[2.1]
  TABLE_NAME = 'users'
  INDEX_NAME = 'index_users_on_updated_at'

  disable_ddl_transaction!

  def up
    add_concurrent_index TABLE_NAME, :updated_at, name: INDEX_NAME
  end

  def down
    remove_concurrent_index_by_name TABLE_NAME, INDEX_NAME
  end
end
