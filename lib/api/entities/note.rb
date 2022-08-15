# frozen_string_literal: true

module API
  module Entities
    class Note < Grape::Entity
      # Only Issue and MergeRequest have iid
      NOTEABLE_TYPES_WITH_IID = %w(Issue MergeRequest).freeze

      expose :id
      expose :type
      expose :note, as: :body
      expose :attachment_identifier, as: :attachment
      expose :author, using: Entities::UserBasic
      expose :created_at, :updated_at
      expose :system?, as: :system
      expose :noteable_id, :noteable_type
      expose :commit_id, if: ->(note, options) { note.noteable_type == "MergeRequest" && note.is_a?(DiffNote) }

      expose :position, if: ->(note, options) { note.is_a?(DiffNote) } do |note|
        note.position.to_h
      end

      expose :resolvable?, as: :resolvable
      expose :resolved?, as: :resolved, if: ->(note, options) { note.resolvable? }
      expose :resolved_by, using: Entities::UserBasic, if: ->(note, options) { note.resolvable? }
      expose :resolved_at, if: ->(note, options) { note.resolvable? }

      expose :confidential?, as: :confidential
      expose :confidential?, as: :internal

      # Avoid N+1 queries as much as possible
      expose(:noteable_iid) { |note| note.noteable.iid if NOTEABLE_TYPES_WITH_IID.include?(note.noteable_type) }

      expose(:commands_changes) { |note| note.commands_changes || {} }
    end

    # To be returned if the note was command-only
    class NoteCommands < Grape::Entity
      expose(:commands_changes) { |note| note.commands_changes || {} }
      expose(:summary) { |note| note.errors[:commands_only] }
    end
  end
end
