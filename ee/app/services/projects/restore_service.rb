# frozen_string_literal: true

module Projects
  class RestoreService < BaseService
    include Gitlab::Utils::StrongMemoize

    DELETED_SUFFIX_REGEX = /-deleted-[a-zA-Z0-9]+\z/

    def execute
      return error(_('Project already deleted')) if project.pending_delete?

      result = ::Projects::UpdateService.new(
        project,
        current_user,
        { archived: false,
          hidden: false,
          marked_for_deletion_at: nil,
          deleting_user: nil,
          name: updated_value(project.name),
          path: updated_value(project.path) }
      ).execute

      if result[:status] == :success
        log_event

        ## Trigger root namespace statistics refresh, to add project_statistics of
        ## projects restored from deletion
        Namespaces::ScheduleAggregationWorker.perform_async(project.namespace_id)
      end

      result
    end

    def log_event
      log_audit_event
      log_info("User #{current_user.id} restored project #{project.full_path}")
    end

    def log_audit_event
      audit_context = {
        name: 'project_restored',
        author: current_user,
        scope: project,
        target: project,
        message: 'Project restored'
      }

      ::Gitlab::Audit::Auditor.audit(audit_context)
    end

    private

    def suffix
      strong_memoize(:suffix) do
        original_path_taken?(project) ? "-#{SecureRandom.alphanumeric(5)}" : ""
      end
    end

    def original_path_taken?(project)
      existing_project = ::Project.find_by_full_path(original_value(project.full_path))

      existing_project.present? && existing_project.id != project.id
    end

    def original_value(value)
      value.sub(DELETED_SUFFIX_REGEX, '')
    end

    def updated_value(value)
      "#{original_value(value)}#{suffix}"
    end
  end
end
