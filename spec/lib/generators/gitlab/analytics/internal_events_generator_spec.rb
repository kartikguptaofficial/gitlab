# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::InternalEventsGenerator, :silence_stdout, feature_category: :service_ping do
  include UsageDataHelpers

  let(:temp_dir) { Dir.mktmpdir }
  let(:tmpfile) { Tempfile.new('test-metadata') }
  let(:ee_temp_dir) { Dir.mktmpdir }
  let(:existing_key_paths) { {} }
  let(:description) { "This metric counts unique users viewing analytics metrics dashboard section" }
  let(:group) { "group::analytics instrumentation" }
  let(:stage) { "analytics" }
  let(:section) { "analytics" }
  let(:mr) { "https://gitlab.com/some-group/some-project/-/merge_requests/123" }
  let(:event) { "view_analytics_dashboard" }
  let(:unique_on) { "user_id" }
  let(:options) do
    {
      time_frames: time_frames,
      free: true,
      mr: mr,
      group: group,
      stage: stage,
      section: section,
      event: event,
      unique_on: unique_on
    }.stringify_keys
  end

  let(:key_path_7d) { "count_distinct_#{unique_on}_from_#{event}_7d" }
  let(:metric_definition_path_7d) { Dir.glob(File.join(temp_dir, "metrics/counts_7d/#{key_path_7d}.yml")).first }
  let(:metric_definition_7d) do
    {
      "key_path" => key_path_7d,
      "name" => key_path_7d,
      "description" => description,
      "product_section" => section,
      "product_stage" => stage,
      "product_group" => group,
      "performance_indicator_type" => [],
      "value_type" => "number",
      "status" => "active",
      "milestone" => "13.9",
      "introduced_by_url" => mr,
      "time_frame" => "7d",
      "data_source" => "redis_hll",
      "data_category" => "optional",
      "instrumentation_class" => "RedisHLLMetric",
      "distribution" => %w[ce ee],
      "tier" => %w[free premium ultimate]
    }
  end

  before do
    stub_const("#{described_class}::TOP_LEVEL_DIR", temp_dir)
    stub_const("#{described_class}::TOP_LEVEL_DIR_EE", ee_temp_dir)
    stub_const("#{described_class}::KNOWN_EVENTS_PATH", tmpfile.path)
    stub_const("#{described_class}::KNOWN_EVENTS_PATH_EE", tmpfile.path)

    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:ask)
                           .with(/Please describe in at least 50 characters/)
                           .and_return(description)
    end

    allow(Gitlab::Usage::MetricDefinition)
      .to receive(:definitions).and_return(existing_key_paths)
  end

  after do
    FileUtils.rm_rf(temp_dir)
    FileUtils.rm_rf(ee_temp_dir)
    FileUtils.rm_rf(tmpfile.path)
  end

  describe 'Creating metric definition file' do
    before do
      # Stub version so that `milestone` key remains constant between releases to prevent flakiness.
      stub_const('Gitlab::VERSION', '13.9.0')
    end

    context 'for single time frame' do
      let(:time_frames) { %w[7d] }

      it 'creates a metric definition file using the template' do
        described_class.new([], options).invoke_all

        expect(YAML.safe_load(File.read(metric_definition_path_7d))).to eq(metric_definition_7d)
      end

      context 'for ultimate only feature' do
        let(:metric_definition_path_7d) do
          Dir.glob(File.join(ee_temp_dir, temp_dir, "metrics/counts_7d/#{key_path_7d}.yml")).first
        end

        it 'creates a metric definition file using the template' do
          described_class.new([], options.merge(tiers: %w[ultimate])).invoke_all

          expect(YAML.safe_load(File.read(metric_definition_path_7d)))
            .to eq(metric_definition_7d.merge("tier" => ["ultimate"], "distribution" => ["ee"]))
        end
      end

      context 'with invalid time frame' do
        let(:time_frames) { %w[14d] }

        it 'raises error' do
          expect { described_class.new([], options).invoke_all }.to raise_error(RuntimeError)
        end
      end

      context 'with duplicated key path' do
        let(:existing_key_paths) { { key_path_7d => true } }

        it 'raises error' do
          expect { described_class.new([], options).invoke_all }.to raise_error(RuntimeError)
        end
      end

      context 'without at least one tier available' do
        it 'raises error' do
          expect { described_class.new([], options.merge(tiers: [])).invoke_all }
            .to raise_error(RuntimeError)
        end
      end

      context 'with unknown tier' do
        it 'raises error' do
          expect { described_class.new([], options.merge(tiers: %w[superb])).invoke_all }
            .to raise_error(RuntimeError)
        end
      end

      context 'without obligatory parameter' do
        it 'raises error', :aggregate_failures do
          %w[unique_on event mr section stage group].each do |option|
            expect { described_class.new([],  options.without(option)).invoke_all }
              .to raise_error(RuntimeError)
          end
        end
      end

      context 'with to short description' do
        it 'asks again for description' do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:ask)
                                 .with(/Please describe in at least 50 characters/)
                                 .and_return("I am to short")

            expect(instance).to receive(:ask)
                                 .with(/Please provide description that is 50 characters long/)
                                 .and_return(description)
          end

          described_class.new([], options).invoke_all
        end
      end
    end

    context 'for multiple time frames' do
      let(:time_frames) { %w[7d 28d] }
      let(:key_path_28d) { "count_distinct_#{unique_on}_from_#{event}_28d" }
      let(:metric_definition_path_28d) { Dir.glob(File.join(temp_dir, "metrics/counts_28d/#{key_path_28d}.yml")).first }
      let(:metric_definition_28d) do
        metric_definition_7d.merge(
          "key_path" => key_path_28d,
          "name" => key_path_28d,
          "time_frame" => "28d"
        )
      end

      it 'creates a metric definition file using the template' do
        described_class.new([], options).invoke_all

        expect(YAML.safe_load(File.read(metric_definition_path_7d))).to eq(metric_definition_7d)
        expect(YAML.safe_load(File.read(metric_definition_path_28d))).to eq(metric_definition_28d)
      end
    end

    context 'with default time frames' do
      let(:time_frames) { nil }
      let(:key_path_28d) { "count_distinct_#{unique_on}_from_#{event}_28d" }
      let(:metric_definition_path_28d) { Dir.glob(File.join(temp_dir, "metrics/counts_28d/#{key_path_28d}.yml")).first }
      let(:metric_definition_28d) do
        metric_definition_7d.merge(
          "key_path" => key_path_28d,
          "name" => key_path_28d,
          "time_frame" => "28d"
        )
      end

      it 'creates a metric definition file using the template' do
        described_class.new([], options.without('time_frames')).invoke_all

        expect(YAML.safe_load(File.read(metric_definition_path_7d))).to eq(metric_definition_7d)
        expect(YAML.safe_load(File.read(metric_definition_path_28d))).to eq(metric_definition_28d)
      end
    end
  end

  describe 'Creating known event entry' do
    let(:time_frames) { %w[7d 28d] }
    let(:expected_known_events) { [{ "name" => event, "aggregation" => "weekly" }] }

    it 'creates a metric definition file using the template' do
      described_class.new([], options).invoke_all

      expect(YAML.safe_load(File.read(tmpfile.path))).to match_array(expected_known_events)
    end

    context 'for ultimate only feature' do
      let(:ee_tmpfile) { Tempfile.new('test-metadata') }

      after do
        FileUtils.rm_rf(ee_tmpfile)
      end

      it 'creates a metric definition file using the template' do
        stub_const("#{described_class}::KNOWN_EVENTS_PATH_EE", ee_tmpfile.path)

        described_class.new([], options.merge(tiers: %w[ultimate])).invoke_all

        expect(YAML.safe_load(File.read(tmpfile.path))).to be nil
        expect(YAML.safe_load(File.read(ee_tmpfile.path))).to match_array(expected_known_events)
      end
    end
  end
end
