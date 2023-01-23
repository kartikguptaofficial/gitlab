# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics, feature_category: :planning_analytics do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:not_member_user) { create(:user) }
  let_it_be(:group) { create(:group).tap { |g| g.add_developer(user) } }

  let_it_be(:models) do
    {
      nil: nil,
      issue: create(:issue),
      project_namespace: create(:project, group: group).reload.project_namespace,
      group: group
    }
  end

  let_it_be(:users) do
    {
      nil: nil,
      member: user,
      not_member: not_member_user
    }
  end

  describe '.licensed?' do
    where(:model, :enabled_license, :outcome) do
      :nil | nil | false
      :issue | nil | false
      :issue | :cycle_analytics_for_projects | false
      :issue | :cycle_analytics_for_groups | false
      :project_namespace | nil | false
      :project_namespace | :cycle_analytics_for_groups | false
      :project_namespace | :cycle_analytics_for_projects | true
      :group | nil | false
      :group | :cycle_analytics_for_groups | true
      :group | :cycle_analytics_for_projects | false
    end

    with_them do
      subject { described_class.licensed?(models.fetch(model)) }

      before do
        stub_licensed_features(enabled_license => true) if enabled_license
      end

      it { is_expected.to eq(outcome) }
    end
  end

  describe '.allowed?' do
    where(:model, :user, :outcome) do
      :nil | :member | false
      :issue | :member | false
      :issue | :not_member | false
      :project_namespace | :nil | false
      :project_namespace | :member | true
      :project_namespace | :not_member | false
      :group | :nil | false
      :group | :member | true
      :group | :not_member | false
    end

    before do
      stub_licensed_features(cycle_analytics_for_projects: true, cycle_analytics_for_groups: true)
    end

    with_them do
      subject { described_class.allowed?(users.fetch(user), models.fetch(model)) }

      it { is_expected.to eq(outcome) }
    end
  end
end
