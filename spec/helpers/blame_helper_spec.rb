# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BlameHelper, feature_category: :source_code_management do
  describe '#get_age_map_start_date' do
    let(:dates) do
      [Time.zone.local(2014, 3, 17, 0, 0, 0),
       Time.zone.local(2011, 11, 2, 0, 0, 0),
       Time.zone.local(2015, 7, 9, 0, 0, 0),
       Time.zone.local(2013, 2, 24, 0, 0, 0),
       Time.zone.local(2010, 9, 22, 0, 0, 0)]
    end

    let(:blame_groups) do
      [
        { commit: double(committed_date: dates[0]) },
        { commit: double(committed_date: dates[1]) },
        { commit: double(committed_date: dates[2]) }
      ]
    end

    it 'returns the earliest date from a blame group' do
      project = double(created_at: dates[3])

      duration = helper.age_map_duration(blame_groups, project)

      expect(duration[:started_days_ago]).to eq((duration[:now] - dates[1]).to_i / 1.day)
    end

    it 'returns the earliest date from a project' do
      project = double(created_at: dates[4])

      duration = helper.age_map_duration(blame_groups, project)

      expect(duration[:started_days_ago]).to eq((duration[:now] - dates[4]).to_i / 1.day)
    end
  end

  describe '#age_map_class' do
    let(:date) { Time.zone.local(2014, 3, 17, 0, 0, 0) }
    let(:blame_groups) { [{ commit: double(committed_date: date) }] }
    let(:duration) do
      project = double(created_at: date)
      helper.age_map_duration(blame_groups, project)
    end

    it 'returns blame-commit-age-9 when oldest' do
      expect(helper.age_map_class(date, duration)).to eq 'blame-commit-age-9'
    end

    it 'returns blame-commit-age-0 class when newest' do
      expect(helper.age_map_class(duration[:now], duration)).to eq 'blame-commit-age-0'
    end

    context 'when called on the same day as project creation' do
      let(:same_day_duration) do
        project = double(created_at: now)
        helper.age_map_duration(today_blame_groups, project)
      end

      let(:today_blame_groups) { [{ commit: double(committed_date: now) }] }
      let(:now) { Time.zone.now }

      it 'returns blame-commit-age-0 class' do
        expect(helper.age_map_class(duration[:now], same_day_duration)).to eq 'blame-commit-age-0'
      end
    end
  end

  describe '#entire_blame_path' do
    subject { helper.entire_blame_path(id, project, blame_mode) }

    let_it_be(:project) { build_stubbed(:project) }

    let(:id) { 'main/README.md' }
    let(:blame_mode) { instance_double('Gitlab::Git::BlameMode', 'streaming_supported?' => streaming_enabled) }

    context 'when streaming is supported' do
      let(:streaming_enabled) { true }

      it { is_expected.to eq "/#{project.full_path}/-/blame/#{id}/streaming" }
    end

    context 'when streaming is not supported' do
      let(:streaming_enabled) { false }

      it { is_expected.to eq "/#{project.full_path}/-/blame/#{id}?no_pagination=true" }
    end
  end
end
