# frozen_string_literal: true

module AlertManagement
  class CreateAlertIssueService
    include Gitlab::Utils::StrongMemoize

    # @param alert [AlertManagement::Alert]
    # @param user [User]
    def initialize(alert, user)
      @alert = alert
      @user = user
    end

    def execute
      return error_no_permissions unless allowed?
      return error_issue_already_exists if alert.issue

      result = create_issue
      issue = result.payload[:issue]

      return error(result.message, issue) if result.error?
      return error(object_errors(alert), issue) unless associate_alert_with_issue(issue)

      result
    end

    private

    attr_reader :alert, :user

    delegate :project, to: :alert

    def allowed?
      user.can?(:create_issue, project)
    end

    def create_issue
      label_result = find_or_create_incident_label

      # Create an unlabelled issue if we couldn't create the label
      # due to a race condition.
      # See https://gitlab.com/gitlab-org/gitlab-foss/issues/65042
      extra_params = label_result.success? ? { label_ids: [label_result.payload[:label].id] } : {}

      issue = Issues::CreateService.new(
        project,
        user,
        title: alert_presenter.title,
        description: alert_presenter.issue_description,
        **extra_params
      ).execute

      return error(object_errors(issue), issue) unless issue.valid?

      success(issue)
    end

    def associate_alert_with_issue(issue)
      alert.update(issue_id: issue.id)
    end

    def success(issue)
      ServiceResponse.success(payload: { issue: issue })
    end

    def error(message, issue = nil)
      ServiceResponse.error(payload: { issue: issue }, message: message)
    end

    def error_issue_already_exists
      error(_('An issue already exists'))
    end

    def error_no_permissions
      error(_('You have no permissions'))
    end

    def alert_presenter
      strong_memoize(:alert_presenter) do
        alert.present
      end
    end

    def find_or_create_incident_label
      IncidentManagement::CreateIncidentLabelService.new(project, user).execute
    end

    def object_errors(object)
      object.errors.full_messages.to_sentence
    end
  end
end
