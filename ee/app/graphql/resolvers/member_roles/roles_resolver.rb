# frozen_string_literal: true

module Resolvers
  module MemberRoles
    class RolesResolver < BaseResolver
      include LooksAhead
      type Types::MemberRoles::MemberRoleType, null: true

      argument :id, ::Types::GlobalIDType[::MemberRole],
        required: false,
        description: 'Global ID of the member role to look up.'

      def resolve_with_lookahead(id: nil)
        params = {}
        params = { parent: object } if object
        params[:id] = id.model_id if id.present?
        params[:instance_roles] = true if instance_roles?(params)

        member_roles = ::MemberRoles::RolesFinder.new(current_user, params).execute
        member_roles = member_roles.with_members_count if selects_field?(:members_count)

        offset_pagination(member_roles)
      end

      private

      def selected_fields
        node_selection.selections.map(&:name)
      end

      def selects_field?(name)
        lookahead.selects?(:members_count) || selected_fields.include?(name)
      end

      def instance_roles?(params)
        return false if params[:id]
        return false if object

        true
      end
    end
  end
end
