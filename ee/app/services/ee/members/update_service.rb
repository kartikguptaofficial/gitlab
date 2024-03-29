# frozen_string_literal: true

module EE
  module Members
    module UpdateService
      extend ActiveSupport::Concern

      def after_execute(action:, old_access_level:, old_expiry:, member:)
        super

        log_audit_event(old_access_level: old_access_level, old_expiry: old_expiry, member: member)
      end

      private

      def update_member(member, permission)
        handle_member_role_assignement(member) if params.key?(:member_role_id)

        super
      end

      def handle_member_role_assignement(member)
        top_level_group = member.source.root_ancestor

        params.delete(:member_role_id) unless top_level_group.custom_roles_enabled?

        return unless params[:member_role_id]

        member_role = top_level_group.member_roles.find_by_id(params[:member_role_id])

        unless member_role
          member.errors.add(:member_role, "not found")
          params.delete(:member_role_id)

          return
        end

        return if params[:access_level]

        params[:access_level] ||= member_role.base_access_level
      end

      def log_audit_event(old_access_level:, old_expiry:, member:)
        audit_context = {
          name: 'member_updated',
          author: current_user || ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)'),
          scope: member.source,
          target: member.user || ::Gitlab::Audit::NullTarget.new,
          target_details: member.user&.name || 'Updated Member',
          message: 'Membership updated',
          additional_details: {
            change: 'access_level',
            from: old_access_level,
            to: member.human_access,
            expiry_from: old_expiry,
            expiry_to: member.expires_at,
            as: ::Gitlab::Access.options_with_owner.key(member.access_level.to_i),
            member_id: member.id
          }
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end
    end
  end
end
