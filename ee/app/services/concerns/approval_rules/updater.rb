# frozen_string_literal: true

module ApprovalRules
  module Updater
    include ::Audit::Changes

    def action
      filter_eligible_users!
      filter_eligible_groups!
      filter_eligible_protected_branches!

      return save_rule_without_audit unless current_user

      if with_audit_logged { rule.update(params) }
        log_audit_event(rule)
        rule.reset

        success
      else
        error(rule.errors.messages)
      end
    end

    private

    def save_rule_without_audit
      if rule.update(params)
        rule.reset

        success
      else
        error(rule.errors.messages)
      end
    end

    def with_audit_logged(&block)
      name = rule.new_record? ? 'approval_rule_created' : 'update_approval_rules'
      audit_context = {
        name: name,
        author: current_user,
        scope: container,
        target: rule
      }

      ::Gitlab::Audit::Auditor.audit(audit_context, &block)
    end

    def filter_eligible_users!
      return unless params.key?(:user_ids) || params.key?(:usernames)

      users = User.by_ids_or_usernames(params.delete(:user_ids), params.delete(:usernames))
      if group_container?
        filter_group_members(users)
      else
        filter_project_members(users)
      end
    end

    def filter_project_members(users)
      params[:users] = rule.project.members_among(users)
    end

    def filter_group_members(users)
      users_ids_of_direct_members = rule.group.users_ids_of_direct_members
      params[:users] = users.select { |user| users_ids_of_direct_members.include?(user.id) }
    end

    def filter_eligible_groups!
      return unless params.key?(:group_ids)

      group_ids = params.delete(:group_ids)

      params[:groups] = if params.delete(:permit_inaccessible_groups)
                          Group.id_in(group_ids)
                        else
                          Group.id_in(group_ids).accessible_to_user(current_user)
                        end
    end

    def filter_eligible_protected_branches!
      return unless params.key?(:protected_branch_ids)

      protected_branch_ids = params.delete(:protected_branch_ids)

      # Currently group approval rules support only all protected branches.
      return if group_container?

      return unless project.multiple_approval_rules_available? &&
        (skip_authorization || can?(current_user, :admin_project, project))

      params[:protected_branches] =
        ProtectedBranch
          .id_in(protected_branch_ids)
          .for_project(project)

      return unless allow_protected_branches_for_group?(project.group) && project.root_namespace.is_a?(Group)

      params[:protected_branches] +=
        ProtectedBranch.id_in(protected_branch_ids).for_group(project.root_namespace)
    end

    def allow_protected_branches_for_group?(group)
      ::Feature.enabled?(:group_protected_branches, group) ||
        ::Feature.enabled?(:allow_protected_branches_for_group, group)
    end

    def log_audit_event(rule)
      audit_changes(
        :approvals_required,
        as: 'number of required approvals',
        entity: container,
        model: rule,
        event_type: 'update_approval_rules'
      )
    end
  end
end
