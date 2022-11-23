# frozen_string_literal: true

return if Rails.env.production?

require 'pact/tasks/verification_task'

provider = File.expand_path('../../../spec/contracts/provider', __dir__)

namespace :contracts do
  require_relative "../../../spec/contracts/provider/helpers/contract_source_helper"

  namespace :merge_requests do
    Pact::VerificationTask.new(:diffs_batch) do |pact|
      pact.uri(
        Provider::ContractSourceHelper.contract_location(:GET_DIFFS_BATCH, :rake),
        pact_helper: "#{provider}/pact_helpers/project/merge_request/show/diffs_batch_helper.rb"
      )
    end

    Pact::VerificationTask.new(:diffs_metadata) do |pact|
      pact.uri(
        Provider::ContractSourceHelper.contract_location(:GET_DIFFS_METADATA, :rake),
        pact_helper: "#{provider}/pact_helpers/project/merge_request/show/diffs_metadata_helper.rb"
      )
    end

    Pact::VerificationTask.new(:discussions) do |pact|
      pact.uri(
        Provider::ContractSourceHelper.contract_location(:GET_DISCUSSIONS, :rake),
        pact_helper: "#{provider}/pact_helpers/project/merge_request/show/discussions_helper.rb"
      )
    end

    desc 'Run all merge request contract tests'
    task 'test:merge_requests', :contract_merge_requests do |_t, arg|
      errors = %w[diffs_batch diffs_metadata discussions].each_with_object([]) do |task, err|
        Rake::Task["contracts:merge_requests:pact:verify:#{task}"].execute
      rescue StandardError, SystemExit
        err << "contracts:merge_requests:pact:verify:#{task}"
      end

      raise StandardError, "Errors in tasks #{errors.join(', ')}" unless errors.empty?
    end
  end
end
