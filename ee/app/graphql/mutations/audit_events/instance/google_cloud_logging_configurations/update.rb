# frozen_string_literal: true

module Mutations
  module AuditEvents
    module Instance
      module GoogleCloudLoggingConfigurations
        class Update < Base
          graphql_name 'InstanceGoogleCloudLoggingConfigurationUpdate'

          include Mutations::AuditEvents::GoogleCloudLoggingConfigurations::CommonUpdate

          UPDATE_EVENT_NAME = 'instance_google_cloud_logging_configuration_updated'

          argument :id, ::Types::GlobalIDType[::AuditEvents::Instance::GoogleCloudLoggingConfiguration],
            required: true,
            description: 'ID of the instance google Cloud configuration to update.'

          field :instance_google_cloud_logging_configuration,
            ::Types::AuditEvents::Instance::GoogleCloudLoggingConfigurationType,
            null: true,
            description: 'configuration updated.'

          def resolve(
            id:,
            google_project_id_name: nil,
            client_email: nil,
            private_key: nil,
            log_id_name: nil,
            name: nil
          )
            config, errors = update_config(id: id, google_project_id_name: google_project_id_name,
              client_email: client_email, private_key: private_key,
              log_id_name: log_id_name, name: name)

            { instance_google_cloud_logging_configuration: config, errors: errors }
          end

          private

          def audit_update(config)
            AUDIT_EVENT_COLUMNS.each do |column|
              audit_changes(
                column,
                as: column.to_s,
                entity: Gitlab::Audit::InstanceScope.new,
                model: config,
                event_type: UPDATE_EVENT_NAME,
                target_details: config.name
              )
            end
          end
        end
      end
    end
  end
end
