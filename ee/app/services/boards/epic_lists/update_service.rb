# frozen_string_literal: true

module Boards
  module EpicLists
    class UpdateService < ::Boards::Lists::BaseUpdateService
      def can_read?(list)
        Ability.allowed?(current_user, :read_epic_board_list, parent)
      end

      def can_admin?(list)
        Ability.allowed?(current_user, :admin_epic_board_list, parent)
      end
    end
  end
end
