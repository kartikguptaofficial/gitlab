# frozen_string_literal: true

class DeprecateCiEditorAiConversationRelatedWorkers < Gitlab::Database::Migration[2.2]
  DEPRECATED_JOB_CLASSES = %w[
    Ci::LLM::GenerateConfigWorker
    OpenAi::ClearConversationsWorker
  ]

  disable_ddl_transaction!

  milestone '16.8'

  def up
    sidekiq_remove_jobs(job_klasses: DEPRECATED_JOB_CLASSES)
  end

  def down
    # This migration removes any instances of deprecated workers and cannot be undone.
  end
end
