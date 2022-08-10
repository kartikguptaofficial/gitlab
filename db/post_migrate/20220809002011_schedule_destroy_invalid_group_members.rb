# frozen_string_literal: true

class ScheduleDestroyInvalidGroupMembers < Gitlab::Database::Migration[2.0]
  MIGRATION = 'DestroyInvalidGroupMembers'
  DELAY_INTERVAL = 2.minutes
  BATCH_SIZE = 1_000
  MAX_BATCH_SIZE = 2_000
  SUB_BATCH_SIZE = 50
  BATCH_CLASS_NAME = 'InvalidGroupMembersBatchingStrategy'

  restrict_gitlab_migration gitlab_schema: :gitlab_main

  disable_ddl_transaction!

  def up
    queue_batched_background_migration(
      MIGRATION,
      :members,
      :id,
      job_interval: DELAY_INTERVAL,
      batch_size: BATCH_SIZE,
      max_batch_size: MAX_BATCH_SIZE,
      sub_batch_size: SUB_BATCH_SIZE,
      batch_class_name: BATCH_CLASS_NAME,
      gitlab_schema: :gitlab_main
    )
  end

  def down
    delete_batched_background_migration(MIGRATION, :members, :id, [])
  end
end
