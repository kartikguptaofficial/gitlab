# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        class SlashCommandTool < Tool
          extend ::Gitlab::Utils::Override

          private

          attr_reader :command

          override :prompt_options
          def prompt_options
            super.merge(command_options).merge(selected_text_options)
          end

          def selected_text_options
            {
              selected_text: context.current_file[:selected_text].to_s,
              file_content: file_content,
              language_info: language_info
            }
          end

          def command_options
            return {} unless command

            command.prompt_options
          end

          def file_content
            return '' unless Feature.enabled?(:slash_commands_file_content, context.current_user)

            content = trimmed_content
            return '' unless content

            partial = content[:is_trimmed] ? 'a part of ' : ''

            <<~TEXT
              Here is #{partial}the content of the file user is working with:
              <file>
                #{content[:content]}
              </file>
            TEXT
          end

          def trimmed_content
            file = context.current_file
            return unless file[:content_above_cursor].present? || file[:content_below_cursor].present?

            max_size = provider_prompt_class::MAX_CHARACTERS / 10
            above = file[:content_above_cursor].to_s.last(max_size)
            below = file[:content_below_cursor].to_s.first(max_size - above.size)
            is_trimmed = above.size < file[:content_above_cursor].to_s.size ||
              below.size < file[:content_below_cursor].to_s.size

            {
              content: "#{above}#{file[:selected_text]}#{below}",
              is_trimmed: is_trimmed
            }
          end

          def language_info
            filename = context.current_file[:file_name].to_s
            language = ::CodeSuggestions::ProgrammingLanguage.detect_from_filename(filename)
            return '' unless language.name.present?

            "The code is written in #{language.name} and stored as #{filename}"
          end
        end
      end
    end
  end
end
