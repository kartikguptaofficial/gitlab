# frozen_string_literal: true

module EE
  module Sidebars
    module YourWork
      module Panel
        extend ::Gitlab::Utils::Override

        override :configure_menus
        def configure_menus
          super

          add_menu(environments_dashboard_menu)
          add_menu(operations_dashboard_menu)

          true
        end

        private

        def environments_dashboard_menu
          ::Sidebars::YourWork::Menus::EnvironmentsDashboardMenu.new(context)
        end

        def operations_dashboard_menu
          ::Sidebars::YourWork::Menus::OperationsDashboardMenu.new(context)
        end
      end
    end
  end
end
