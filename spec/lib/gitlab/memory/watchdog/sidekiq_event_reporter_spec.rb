# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Memory::Watchdog::SidekiqEventReporter, feature_category: :application_performance do
  let(:counter) { instance_double(::Prometheus::Client::Counter) }

  before do
    allow(Gitlab::Metrics).to receive(:counter).and_return(counter)
    allow(counter).to receive(:increment)
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:started).to(:event_reporter) }
    it { is_expected.to delegate_method(:stopped).to(:event_reporter) }
    it { is_expected.to delegate_method(:threshold_violated).to(:event_reporter) }
    it { is_expected.to delegate_method(:logger).to(:event_reporter) }
  end

  describe '#strikes_exceeded' do
    let(:sidekiq_event_reporter) { described_class.new(logger: logger) }
    let(:sidekiq_watchdog_running_jobs_counter) { instance_double(::Prometheus::Client::Counter) }
    let(:logger) { instance_double(::Logger) }
    let(:queue) { 'default' }
    let(:jid) { SecureRandom.hex }
    let(:running_jobs) { { jid => { worker_class: DummyWorker } } }
    let(:worker) do
      Class.new do
        def self.name
          'DummyWorker'
        end
      end
    end

    before do
      stub_const("DummyWorker", worker)
      allow(::Gitlab::Metrics).to receive(:counter)
        .with(:sidekiq_watchdog_running_jobs_total, anything)
        .and_return(sidekiq_watchdog_running_jobs_counter)
      allow(sidekiq_watchdog_running_jobs_counter).to receive(:increment)
      allow(logger).to receive(:warn)

      allow(Gitlab::SidekiqDaemon::Monitor.instance).to receive(:with_running_jobs).and_yield(running_jobs)
    end

    it 'delegates #strikes_exceeded with correct arguments' do
      is_expected.to delegate_method(:strikes_exceeded).to(:event_reporter)
       .with_arguments(
         :monitor_name,
         {
           message: 'dummy_text',
           running_jobs: running_jobs
         }
       )
    end

    it 'increment running jobs counter' do
      expect(sidekiq_watchdog_running_jobs_counter).to receive(:increment)
        .with({ worker_class: "DummyWorker" })

      sidekiq_event_reporter.strikes_exceeded(:monitor_name, { message: 'dummy_text' })
    end
  end
end
