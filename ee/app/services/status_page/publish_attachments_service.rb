# frozen_string_literal: true

module StatusPage
  # Publishes Attachments from incident comments and descriptions to s3
  # Should only be called from publish details or a service that inherits from the publish_base_service
  class PublishAttachmentsService
    include StatusPage::PublicationServiceHelpers

    def initialize(project:, issue:, user_notes:, storage_client:)
      @project = project
      @issue = issue
      @user_notes = user_notes
      @storage_client = storage_client
      @total_uploads = existing_keys.size
    end

    def execute
      publish_description_attachments
      publish_user_note_attachments

      success
    end

    private

    attr_reader :project, :issue, :user_notes, :storage_client

    def publish_description_attachments
      publish_markdown_uploads(
        markdown_field: issue.description,
        issue_iid: issue.iid
      )
    end

    def publish_user_note_attachments
      user_notes.each do |user_note|
        publish_markdown_uploads(
          markdown_field: user_note.note,
          issue_iid: issue.iid
        )
      end
    end

    def publish_markdown_uploads(markdown_field:, issue_iid:)
      markdown_field.scan(FileUploader::MARKDOWN_PATTERN).map do |secret, file_name|
        break if @total_uploads >= StatusPage::Storage::MAX_UPLOADS

        key = StatusPage::Storage.upload_path(issue_iid, secret, file_name)
        next if existing_keys.include? key

        # uploader behaves like a file with an 'open' method
        file = UploaderFinder.new(project, secret, file_name).execute

        upload_file(key, file)
      end
    end

    def upload_file(key, file)
      file.open do |open_file|
        # Send files to s3 storage in parts (hanles large files)
        storage_client.multipart_upload(key, open_file)
        @total_uploads += 1
      end
    end

    def existing_keys
      strong_memoize(:existing_keys) do
        storage_client.list_object_keys(uploads_path)
      end
    end

    def uploads_path
      StatusPage::Storage.uploads_path(issue.iid)
    end
  end
end
