# frozen_string_literal: true

class CreateDastProfilesTags < Gitlab::Database::Migration[2.1]
  def up
    create_table :dast_profiles_tags do |t|
      t.references :dast_profile, null: false, foreign_key: { on_delete: :cascade },
                   index: { name: 'i_dast_profiles_tags_on_scanner_profiles_id' }

      t.bigint :tag_id, null: false

      t.index :tag_id, name: :index_dast_profiles_tags_on_tag_id
    end
  end

  def down
    drop_table :dast_profiles_tags
  end
end
