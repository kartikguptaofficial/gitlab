# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::StatusHelper do
  include IconsHelper

  let(:success_commit) { double("Ci::Pipeline", status: 'success') }
  let(:failed_commit) { double("Ci::Pipeline", status: 'failed') }

  describe "#pipeline_status_cache_key" do
    it "builds a cache key for pipeline status" do
      pipeline_status = Gitlab::Cache::Ci::ProjectPipelineStatus.new(
        build_stubbed(:project),
        pipeline_info: {
          sha: "123abc",
          status: "success"
        }
      )
      expect(helper.pipeline_status_cache_key(pipeline_status)).to eq("pipeline-status/123abc-success")
    end
  end

  describe "#render_ci_icon" do
    subject { helper.render_ci_icon("success") }

    it "has 'Pipeline' as the status type in the title" do
      is_expected.to include("title=\"Pipeline: passed\"")
    end

    it "has the success status icon" do
      is_expected.to include("ci-icon-variant-success")
    end

    context "when pipeline has commit path" do
      subject { helper.render_ci_icon("success", "/commit-path") }

      it "links to commit" do
        is_expected.to include("href=\"/commit-path\"")
      end

      it "has 'Pipeline' as the status type in the title" do
        is_expected.to include("title=\"Pipeline: passed\"")
      end

      it "has the correct status icon" do
        is_expected.to include("ci-icon-variant-success")
      end
    end

    context "when showing status text" do
      subject do
        detailed_status = Gitlab::Ci::Status::Success.new(build(:ci_build, :success), build(:user))
        helper.render_ci_icon(detailed_status, show_status_text: true)
      end

      it "contains status text" do
        is_expected.to include("data-testid=\"ci-icon-text\"")
        is_expected.to include("passed")
      end
    end

    context "when tooltip_placement is provided" do
      subject { helper.render_ci_icon("success", tooltip_placement: "right") }

      it "has the provided tooltip placement" do
        is_expected.to include("data-placement=\"right\"")
      end
    end

    context "when container is provided" do
      subject { helper.render_ci_icon("success", container: "my-container") }

      it "has the provided container in data" do
        is_expected.to include("data-container=\"my-container\"")
      end
    end

    context "when status is success-with-warnings" do
      subject { helper.render_ci_icon("success-with-warnings") }

      it "renders warning variant of gl-badge" do
        is_expected.to include('gl-badge badge badge-pill badge-warning')
      end
    end

    context "when status is manual" do
      subject { helper.render_ci_icon("manual") }

      it "renders neutral variant of gl-badge" do
        is_expected.to include('gl-badge badge badge-pill badge-neutral')
      end
    end

    describe 'badge and icon appearance' do
      using RSpec::Parameterized::TableSyntax

      where(:status, :icon, :badge_variant) do
        'success'               | 'status_success_borderless'   | 'success'
        'success-with-warnings' | 'status_warning_borderless'   | 'warning'
        'pending'               | 'status_pending_borderless'   | 'warning'
        'waiting-for-resource'  | 'status_pending_borderless'   | 'warning'
        'failed'                | 'status_failed_borderless'    | 'danger'
        'running'               | 'status_running_borderless'   | 'info'
        'preparing'             | 'status_preparing_borderless' | 'neutral'
        'canceled'              | 'status_canceled_borderless'  | 'neutral'
        'created'               | 'status_created_borderless'   | 'neutral'
        'scheduled'             | 'status_scheduled_borderless' | 'neutral'
        'play'                  | 'play'                        | 'neutral'
        'skipped'               | 'status_skipped_borderless'   | 'neutral'
        'manual'                | 'status_manual_borderless'    | 'neutral'
        'other-status'          | 'status_canceled_borderless'  | 'neutral'
      end

      with_them do
        subject { helper.render_ci_icon(status) }

        it 'uses the correct variant and icon for status' do
          is_expected.to include("gl-badge badge badge-pill badge-#{badge_variant}")
          is_expected.to include("ci-icon-variant-#{badge_variant}")
          is_expected.to include("data-testid=\"#{icon}-icon\"")
        end
      end
    end
  end
end
