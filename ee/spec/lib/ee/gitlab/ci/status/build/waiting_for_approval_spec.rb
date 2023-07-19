# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Status::Build::WaitingForApproval, feature_category: :deployment_management do
  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }
  let_it_be(:build) { create(:ci_build, :manual, environment: 'production', project: project) }

  subject { described_class.new(Gitlab::Ci::Status::Core.new(build, user)) }

  describe '.matches?' do
    subject { described_class.matches?(build, user) }

    let(:build) { create(:ci_build, :manual, environment: 'production', project: project) }
    let!(:deployment) { create(:deployment, deployment_status, deployable: build, project: project) }

    context 'when build is waiting for approval' do
      let(:deployment_status) { :blocked }

      before do
        allow(deployment).to receive(:waiting_for_approval?).and_return(true)
      end

      it 'is a correct match' do
        expect(subject).to be_truthy
      end
    end

    context 'when build is not waiting for approval' do
      let(:deployment_status) { :created }

      it 'does not match' do
        expect(subject).to be_falsey
      end
    end
  end

  describe '#illustration' do
    before do
      environment = create(:environment, name: 'production', project: project)
      create(:deployment, :blocked, project: project, environment: environment, deployable: build)
    end

    it { expect(subject.illustration).to include(:image, :size) }
    it { expect(subject.illustration[:title]).to eq('Waiting for approvals') }

    it do
      expect(subject.illustration[:content]).to include('This job deploys to the protected environment "production"')
    end
  end

  describe '#has_action?' do
    it { expect(subject.has_action?).to be_truthy }
  end

  describe '#action_icon' do
    it { expect(subject.action_icon).to be_nil }
  end

  describe '#action_title' do
    it { expect(subject.action_title).to be_nil }
  end

  describe '#action_button_title' do
    it { expect(subject.action_button_title).to eq('View environment details page') }
  end

  describe '#action_path' do
    before do
      environment = create(:environment, name: 'production', project: project)
      create(:deployment, :blocked, project: project, environment: environment, deployable: build)
    end

    it { expect(subject.action_path).to include('environments') }
  end

  describe '#action_method' do
    it { expect(subject.action_method).to eq(:get) }
  end
end
