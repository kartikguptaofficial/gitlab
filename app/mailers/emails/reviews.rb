# frozen_string_literal: true

module Emails
  module Reviews
    def new_review_email(recipient_id, review_id)
      setup_review_email(review_id, recipient_id)

      mail_answer_thread(@merge_request, review_thread_options(recipient_id))
    end

    private

    def review_thread_options(recipient_id)
      {
        from: sender(@author.id),
        to: User.find(recipient_id).notification_email_for(@merge_request.target_project.group),
        subject: subject("#{@merge_request.title} (#{@merge_request.to_reference})")
      }
    end

    def setup_review_email(review_id, recipient_id)
      review = Review.find_by_id(review_id)

      @notes = review.notes
      discussion_ids = @notes.pluck(:discussion_id)
      @discussions = discussions(discussion_ids)
      @author = review.author
      @author_name = review.author_name
      @project = review.project
      @merge_request = review.merge_request
      @target_url = project_merge_request_url(@project, @merge_request)
      @sent_notification = SentNotification.record(@merge_request, recipient_id, reply_key)
    end

    def discussions(discussion_ids)
      notes = Note.where(discussion_id: discussion_ids).inc_note_diff_file.fresh
      grouped_notes = notes.group_by { |n| n.discussion_id }
      grouped_notes.transform_values { |notes| Discussion.build(notes) }
    end
  end
end
