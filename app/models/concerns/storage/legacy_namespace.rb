module Storage
  module LegacyNamespace
    extend ActiveSupport::Concern

    def move_dir
      if any_project_has_container_registry_tags?
        raise Gitlab::UpdatePathError.new('Namespace cannot be moved, because at least one project has tags in container registry')
      end

      # Move the namespace directory in all storage paths used by member projects
      repository_storage_paths.each do |repository_storage_path|
        # Ensure old directory exists before moving it
        gitlab_shell.add_namespace(repository_storage_path, full_path_was)

        unless gitlab_shell.mv_namespace(repository_storage_path, full_path_was, full_path)
          Rails.logger.error "Exception moving path #{repository_storage_path} from #{full_path_was} to #{full_path}"

          # if we cannot move namespace directory we should rollback
          # db changes in order to prevent out of sync between db and fs
          raise Gitlab::UpdatePathError.new('namespace directory cannot be moved')
        end
      end

      Gitlab::UploadsTransfer.new.rename_namespace(full_path_was, full_path)
      Gitlab::PagesTransfer.new.rename_namespace(full_path_was, full_path)

      remove_exports!

      # If repositories moved successfully we need to
      # send update instructions to users.
      # However we cannot allow rollback since we moved namespace dir
      # So we basically we mute exceptions in next actions
      begin
        send_update_instructions
        true
      rescue
        # Returning false does not rollback after_* transaction but gives
        # us information about failing some of tasks
        false
      end
    end

    # Hooks

    # Save the storage paths before the projects are destroyed to use them on after destroy
    def prepare_for_destroy
      old_repository_storage_paths
    end

    private

    def old_repository_storage_paths
      @old_repository_storage_paths ||= repository_storage_paths
    end

    def repository_storage_paths
      # We need to get the storage paths for all the projects, even the ones that are
      # pending delete. Unscoping also get rids of the default order, which causes
      # problems with SELECT DISTINCT.
      Project.unscoped do
        all_projects.select('distinct(repository_storage)').to_a.map(&:repository_storage_path)
      end
    end

    def rm_dir
      # Remove the namespace directory in all storages paths used by member projects
      old_repository_storage_paths.each do |repository_storage_path|
        # Move namespace directory into trash.
        # We will remove it later async
        new_path = "#{full_path}+#{id}+deleted"

        if gitlab_shell.mv_namespace(repository_storage_path, full_path, new_path)
          Gitlab::AppLogger.info %Q(Namespace directory "#{full_path}" moved to "#{new_path}")

          # Remove namespace directroy async with delay so
          # GitLab has time to remove all projects first
          run_after_commit do
            GitlabShellWorker.perform_in(5.minutes, :rm_namespace, repository_storage_path, new_path)
          end
        end
      end

      remove_exports!
    end

    def remove_exports!
      Gitlab::Popen.popen(%W(find #{export_path} -not -path #{export_path} -delete))
    end

    def export_path
      File.join(Gitlab::ImportExport.storage_path, full_path_was)
    end

    def full_path_was
      if parent
        parent.full_path + '/' + path_was
      else
        path_was
      end
    end
  end
end
