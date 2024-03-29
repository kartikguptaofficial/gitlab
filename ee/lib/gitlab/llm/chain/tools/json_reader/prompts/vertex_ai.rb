# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module JsonReader
          module Prompts
            class VertexAi
              include Concerns::VertexAiPrompt

              def self.prompt(options)
                prompt = Utils::Prompt.no_role_text(
                  ::Gitlab::Llm::Chain::Tools::JsonReader::Executor::PROMPT_TEMPLATE, options
                ).concat("\nThought:")

                Requests::VertexAi.prompt(prompt)
              end
            end
          end
        end
      end
    end
  end
end
