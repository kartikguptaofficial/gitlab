# frozen_string_literal: true

module Resolvers
  module MemberRoles
    class PermissionListResolver < BaseResolver
      type Types::MemberRoles::CustomizablePermissionType, null: true

      def resolve
        MemberRole::ALL_CUSTOMIZABLE_PERMISSIONS.map do |permission, definition|
          definition[:requirement] = definition[:requirement]&.to_s&.upcase
          permission = permission.to_s.upcase

          definition.merge(value: permission)
        end
      end
    end
  end
end
