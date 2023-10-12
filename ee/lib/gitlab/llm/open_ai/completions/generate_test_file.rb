# frozen_string_literal: true

module Gitlab
  module Llm
    module OpenAi
      module Completions
        class GenerateTestFile < Gitlab::Llm::Completions::Base
          DEFAULT_ERROR = 'An unexpected error has occurred.'

          def execute
            response = response_for(user, merge_request, options[:file_path])
            response_modifier = Gitlab::Llm::OpenAi::ResponseModifiers::Chat.new(response)

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, merge_request, response_modifier, options: response_options
            ).execute

            response_modifier
          rescue StandardError => error
            Gitlab::ErrorTracking.track_exception(error)

            response_modifier = ::Gitlab::Llm::OpenAi::ResponseModifiers::Chat.new(
              { error: { message: DEFAULT_ERROR } }.to_json
            )

            ::Gitlab::Llm::GraphqlSubscriptionResponseService.new(
              user, merge_request, response_modifier, options: response_options
            ).execute

            response_modifier
          end

          private

          def response_for(user, merge_request, path)
            template = ai_prompt_class.new(merge_request, path)
            client_class = ::Gitlab::Llm::OpenAi::Client
            client_class.new(user, tracking_context: tracking_context)
              .chat(content: template.to_prompt, **template.options(client_class))
          end

          def merge_request
            resource
          end
        end
      end
    end
  end
end
