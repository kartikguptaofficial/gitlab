# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ContributionAnalytics::DataCollector, feature_category: :value_stream_management do
  let_it_be(:group) { create(:group) }
  let_it_be(:project1) { create(:project, group: group) }
  let_it_be(:project2) { create(:project, group: group) }

  describe 'delegated methods' do
    subject { described_class.new(group: group) }

    it { is_expected.to delegate_method(:totals).to(:data_formatter) }
    it { is_expected.to delegate_method(:users).to(:data_formatter) }
  end

  describe 'date range filters' do
    it 'filters the date range' do
      # before the range
      create(:event, :pushed, project: project1, target: nil, created_at: 2.years.ago)
      # after the range
      create(:event, :pushed, project: project1, target: nil, created_at: Date.today)
      # in the range
      create(:event, :pushed, project: project1, target: nil, created_at: 1.year.ago)

      data_collector = described_class.new(group: group, from: 14.months.ago, to: 5.months.ago)

      all_event_count = data_collector.totals[:total_events].values.sum
      expect(all_event_count).to eq(1)
    end
  end

  describe '#totals' do
    it 'collects event counts grouped by users by calling #base_query' do
      user = create(:user)

      issue = create(:closed_issue, project: project1)
      mr = create(:merge_request, source_project: project2)

      create(:event, :closed, project: project1, target: issue, author: user)
      create(:event, :created, project: project2, target: mr, author: user)
      create(:event, :approved, project: project2, target: mr, author: user)
      create(:event, :closed, project: project2, target: mr, author: user)

      data_collector = described_class.new(group: group)
      expect(data_collector.totals).to eq({
        issues_closed: { user.id => 1 },
        issues_created: {},
        merge_requests_created: { user.id => 1 },
        merge_requests_merged: {},
        merge_requests_approved: { user.id => 1 },
        merge_requests_closed: { user.id => 1 },
        push: {},
        total_events: { user.id => 4 }
      })
    end
  end
end
