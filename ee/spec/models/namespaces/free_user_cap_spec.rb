# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::FreeUserCap, feature_category: :measurement_and_locking do
  using RSpec::Parameterized::TableSyntax

  describe '.dashboard_limit' do
    subject { described_class.dashboard_limit }

    context 'when set to default' do
      it { is_expected.to eq 0 }
    end

    context 'when not set to default' do
      before do
        stub_ee_application_setting(dashboard_limit: 5)
      end

      it { is_expected.to eq 5 }
    end
  end

  describe '.dashboard_limit_enabled?' do
    let(:dashboard_limit_enabled) { true }

    subject { described_class.dashboard_limit_enabled? }

    before do
      stub_ee_application_setting(dashboard_limit_enabled: dashboard_limit_enabled)
    end

    context 'when set true' do
      it { is_expected.to be(true) }
    end

    context 'when set to false' do
      let(:dashboard_limit_enabled) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '.over_user_limit_email_enabled?' do
    let(:free_user_cap_over_limit_email_enabled) { true }

    subject { described_class.over_user_limit_email_enabled?(build(:group)) }

    before do
      stub_feature_flags(free_user_cap_over_limit_email: free_user_cap_over_limit_email_enabled)
    end

    context 'when free_user_cap_over_limit_email feature flag is true' do
      it { is_expected.to be(true) }
    end

    context 'when free_user_cap_over_limit_email feature flag is false' do
      let(:free_user_cap_over_limit_email_enabled) { false }

      it { is_expected.to be(false) }
    end
  end

  describe '.owner_access?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    subject(:access) { described_class.owner_access?(user: user, namespace: namespace) }

    context 'when user is not provided' do
      let(:user) { nil }

      it 'returns false' do
        expect(access).to be(false)
      end
    end

    context 'when user does not have owner access' do
      it 'returns false' do
        namespace.add_developer(user)

        expect(access).to be(false)
      end
    end

    context 'when user has owner access' do
      it 'returns true' do
        namespace.add_owner(user)

        expect(access).to be(true)
      end
    end
  end

  describe '.non_owner_access?' do
    let_it_be(:user) { create(:user) }
    let_it_be(:namespace) { create(:group) }

    subject(:access) { described_class.non_owner_access?(user: user, namespace: namespace) }

    context 'when user is not provided' do
      let(:user) { nil }

      it 'returns false' do
        expect(access).to be(false)
      end
    end

    context 'when user does not have owner access' do
      it 'returns true' do
        namespace.add_developer(user)

        expect(access).to be(true)
      end
    end

    context 'when user has owner access' do
      it 'returns false' do
        namespace.add_owner(user)

        expect(access).to be(false)
      end
    end
  end
end
