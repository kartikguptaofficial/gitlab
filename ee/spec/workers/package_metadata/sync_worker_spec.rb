# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PackageMetadata::SyncWorker, type: :worker, feature_category: :license_compliance do
  include_examples 'an idempotent worker' do
    before do
      allow(PackageMetadata::SyncService).to receive(:execute)
    end

    subject do
      perform_multiple([], worker: described_class.new)
    end
  end

  describe '#perform' do
    subject(:perform) { described_class.new.perform }

    context 'with feature flag enabled' do
      it 'calls the sync service to do the work' do
        expect(PackageMetadata::SyncService).to receive(:execute) do |signal|
          expect(signal).to respond_to(:stop?)
        end
        perform
      end
    end

    context 'with feature flag disabled' do
      before do
        stub_feature_flags(package_metadata_synchronization: false)
      end

      it 'does not call the sync service to do the work' do
        expect(PackageMetadata::SyncService).not_to receive(:execute)
        perform
      end
    end

    context 'when exclusive lease could not be obtained' do
      subject(:instance) { described_class.new }

      before do
        allow(instance).to receive(:try_obtain_lease).and_return(false)
      end

      it 'does not call the sync service' do
        expect(PackageMetadata::SyncService).not_to receive(:execute)
        instance.perform
      end
    end
  end

  describe 'stop signal' do
    let(:instance) { described_class.new }
    let(:lease) { instance_double(Gitlab::ExclusiveLease, ttl: ttl) }

    subject(:stop?) { described_class::StopSignal.new(lease).stop? }

    context 'when lease elapsed time is greater than max sync duration' do
      let(:ttl) { described_class::LEASE_TIMEOUT - described_class::MAX_SYNC_DURATION + 1 }

      it { is_expected.to be false }
    end

    context 'when lease elapsed time is the same as max sync duration' do
      let(:ttl) { described_class::LEASE_TIMEOUT - described_class::MAX_SYNC_DURATION }

      it { is_expected.to be false }
    end

    context 'when lease elapsed time is less than max sync duration' do
      let(:ttl) { described_class::LEASE_TIMEOUT - described_class::MAX_SYNC_DURATION - 1 }

      it { is_expected.to be true }
    end
  end
end
