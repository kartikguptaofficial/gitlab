# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Agents::ZeroShot::Prompts::Anthropic, feature_category: :duo_chat do
  include FakeBlobHelpers

  describe '.prompt' do
    let(:prompt_version) { ::Gitlab::Llm::Chain::Agents::ZeroShot::Executor::PROMPT_TEMPLATE }
    let(:options) do
      {
        tools_definitions: "tool definitions",
        tool_names: "tool names",
        user_input: 'foo?',
        agent_scratchpad: "some observation",
        conversation: [
          build(:ai_message, request_id: 'uuid1', role: 'user', content: 'question 1'),
          build(:ai_message, request_id: 'uuid1', role: 'assistant', content: 'response 1'),
          build(:ai_message, request_id: 'uuid1', role: 'user', content: 'question 2'),
          build(:ai_message, request_id: 'uuid1', role: 'assistant', content: 'response 2')
        ],
        prompt_version: prompt_version,
        current_code: "",
        current_resource: "",
        resources: ""
      }
    end

    let(:prompt_text) { "Answer the question as accurate as you can." }

    subject { described_class.prompt(options)[:prompt] }

    it 'returns prompt' do
      expect(subject).to include('Human:')
      expect(subject).to include('Assistant:')
      expect(subject).to include('foo?')
      expect(subject).to include('tool definitions')
      expect(subject).to include('tool names')
      expect(subject).to include(prompt_text)
      expect(subject).to include(Gitlab::Llm::Chain::Utils::Prompt.default_system_prompt)
    end

    it 'includes conversation history' do
      expect(subject)
        .to start_with("Human: question 1\n\nAssistant: response 1\n\nHuman: question 2\n\nAssistant: response 2\n\n")
    end

    context 'when conversation history does not fit prompt limit' do
      before do
        default_size = described_class.prompt(options.merge(conversation: []))[:prompt].size

        stub_const("::Gitlab::Llm::Chain::Requests::Anthropic::PROMPT_SIZE", default_size + 40)
      end

      it 'includes truncated conversation history' do
        expect(subject).to start_with("Assistant: response 2\n\n")
      end
    end
  end

  it_behaves_like 'zero shot prompt'
end
