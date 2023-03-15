# frozen_string_literal: true

module WorkItems
  module Widgets
    module NotificationsService
      class UpdateService < WorkItems::Widgets::BaseService
        def before_update_in_transaction(params:)
          return unless params.present? && params.key?(:subscribed)
          return unless has_permission?(:update_subscription)

          update_subscription(work_item, params)
        end

        private

        def update_subscription(work_item, subscription_params)
          work_item.set_subscription(
            current_user,
            subscription_params[:subscribed],
            work_item.project
          )
        end
      end
    end
  end
end
