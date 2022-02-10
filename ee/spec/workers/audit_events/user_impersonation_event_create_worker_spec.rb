# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::UserImpersonationEventCreateWorker do
  describe "#perform" do
    let_it_be(:impersonator) { create(:admin) }
    let_it_be(:user) { create(:user) }

    let(:action) { :started }

    subject(:worker) { described_class.new }

    it 'invokes the UserImpersonationGroupAuditEventService' do
      expect(::AuditEvents::UserImpersonationGroupAuditEventService).to receive(:new).with(
        impersonator: impersonator,
        user: user,
        remote_ip: '111.112.11.2',
        action: action
      ).and_call_original

      subject.perform(impersonator.id, user.id, '111.112.11.2', action)
    end
  end
end
