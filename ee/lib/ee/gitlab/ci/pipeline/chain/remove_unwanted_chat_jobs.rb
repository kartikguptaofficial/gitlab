# frozen_string_literal: true

module EE
  module Gitlab
    module Ci
      module Pipeline
        module Chain
          module RemoveUnwantedChatJobs
            extend ::Gitlab::Utils::Override

            override :perform!
            def perform!
              return unless pipeline.config_processor && pipeline.chat?

              # When scheduling a chat pipeline we only want to run the build
              # that matches the chat command.
              pipeline.config_processor.jobs.select! do |name, _|
                name.to_s == command.chat_data[:command].to_s
              end
            end
          end
        end
      end
    end
  end
end
