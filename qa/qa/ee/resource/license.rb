# frozen_string_literal: true

module QA
  module EE
    module Resource
      class License < QA::Resource::Base
        def fabricate!(license)
          QA::Page::Main::Login.perform(&:sign_in_using_admin_credentials)
          QA::Page::Main::Menu.perform(&:go_to_admin_area)
          QA::Page::Admin::Menu.perform(&:click_subscription_menu_link)

          EE::Page::Admin::License.perform do |license_page|
            if license_page.license?
              QA::Runtime::Logger.debug("A license already exists.")
            else
              QA::Page::Admin::Menu.perform(&:go_to_general_settings)

              license_page.add_new_license(license)

              license_length = license.to_s.strip.length
              license_info = "TEST_LICENSE_MODE: #{ENV['TEST_LICENSE_MODE']}. License key length: #{license_length}. " + (license_length > 5 ? "Last five characters: #{license.to_s.strip[-5..]}" : "")

              if EE::Page::Admin::Subscription.perform(&:has_ultimate_subscription_plan?)
                QA::Runtime::Logger.debug("Successfully added license key. #{license_info}")
              else
                raise "Adding license key was unsuccessful. #{license_info}"
              end
            end
          end

          QA::Page::Main::Menu.perform(&:sign_out_if_signed_in)
        end
      end
    end
  end
end
