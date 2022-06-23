# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IncidentManagement::IssuableResourceLinks::DestroyService do
  let_it_be(:user_with_permissions) { create(:user) }
  let_it_be(:user_without_permissions) { create(:user) }
  let_it_be(:project) { create(:project) }
  let_it_be(:error_message) { 'You have insufficient permissions to manage resource links for this incident' }
  let_it_be_with_refind(:incident) { create(:incident, project: project) }

  let!(:issuable_resource_link) { create(:issuable_resource_link, issue: incident) }

  let(:current_user) { user_with_permissions }
  let(:params) { {} }
  let(:service) { described_class.new(issuable_resource_link, current_user) }

  before do
    stub_licensed_features(issuable_resource_links: true)
  end

  before_all do
    project.add_reporter(user_with_permissions)
    project.add_guest(user_without_permissions)
  end

  describe '#execute' do
    shared_examples 'error response' do |message|
      it 'has an informative message' do
        error_message_string = message.nil? ? error_message : message

        expect(execute).to be_error
        expect(execute.message).to eq(error_message_string)
      end
    end

    subject(:execute) { service.execute }

    context 'when current user is anonymous' do
      let(:current_user) { nil }

      it_behaves_like 'error response'
    end

    context 'when user does not have permissions to remove issuable_resource_link' do
      let(:current_user) { user_without_permissions }

      it_behaves_like 'error response'
    end

    context 'when feature is not available' do
      before do
        stub_licensed_features(issuable_resource_links: false)
      end

      it_behaves_like 'error response'
    end

    context 'when feature flag is disabled' do
      before do
        stub_feature_flags(incident_resource_links_widget: false)
      end

      it_behaves_like 'error response'
    end

    context 'when an error occurs during removal' do
      before do
        allow(issuable_resource_link).to receive(:destroy).and_return(false)
        issuable_resource_link.errors.add(:link, 'cannot be removed')
      end

      it_behaves_like 'error response', 'Link cannot be removed'
    end

    it 'successfully returns the issuable resource link', :aggregate_failures do
      expect(execute).to be_success

      result = execute.payload[:issuable_resource_link]

      expect(result).to be_a(::IncidentManagement::IssuableResourceLink)
      expect(result.id).to eq(issuable_resource_link.id)
    end
  end
end
