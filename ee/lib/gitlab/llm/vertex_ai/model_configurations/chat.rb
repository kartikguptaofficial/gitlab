# frozen_string_literal: true

module Gitlab
  module Llm
    module VertexAi
      module ModelConfigurations
        class Chat < Base
          include Gitlab::Utils::StrongMemoize

          NAME = 'chat-bison-001'

          def payload(content)
            {
              instances: [
                {
                  messages: content
                }
              ],
              parameters: Configuration.default_payload_parameters
            }
          end

          def url
            text_model_url = URI.parse(tofa_url)
            text_model_url.host = text_model_url.host.gsub('-preprod-', '-')
            text_model_url.path = text_model_url.path
                                    .gsub('vertex-code-assist', 'cloud-large-language-models')
                                    .gsub(ModelConfigurations::CodeChat::NAME, NAME)
            text_model_url.to_s
          end
          strong_memoize_attr :url

          def host
            URI.parse(url).hostname
          end
          strong_memoize_attr :host
        end
      end
    end
  end
end
