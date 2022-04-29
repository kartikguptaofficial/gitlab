# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ReleaseHighlights::Validator::Entry, type: :model do
  subject(:entry) { described_class.new(document.root.children.first) }

  let(:document) { YAML.parse(File.read(yaml_path)) }
  let(:yaml_path) { 'spec/fixtures/whats_new/blank.yml' }

  describe 'validations' do
    before do
      allow(entry).to receive(:value_for).and_call_original
    end

    context 'with a valid entry' do
      let(:yaml_path) { 'spec/fixtures/whats_new/valid.yml' }

      it { is_expected.to be_valid }
    end

    context 'with an invalid entry' do
      let(:yaml_path) { 'spec/fixtures/whats_new/invalid.yml' }

      it { is_expected.to be_invalid }
    end

    context 'with a blank entry' do
      it { is_expected.to validate_presence_of(:name).with_message("can't be blank (line 1)") }
      it { is_expected.to validate_presence_of(:description).with_message("can't be blank (line 2)") }
      it { is_expected.to validate_presence_of(:stage).with_message("can't be blank (line 3)") }
      it { is_expected.to validate_presence_of(:self_managed).with_message("must be a boolean (line 4)") }
      it { is_expected.to validate_presence_of(:gitlab_com).with_message("must be a boolean (line 5)") }
      it { is_expected.to validate_presence_of(:image_url).with_message("can't be blank (line 1)").allow_nil }

      it {
        is_expected.to validate_presence_of(:available_in)
          .with_message("must be one of #{ReleaseHighlights::Validator::Entry::AVAILABLE_IN} (line 1)")
      }

      it { is_expected.to validate_presence_of(:published_at).with_message("must be valid Date (line 8)") }
      it { is_expected.to validate_numericality_of(:release).with_message("is not a number (line 9)") }

      it 'validates URI of "documentation_link" and "image_url"' do
        stub_env('RSPEC_ALLOW_INVALID_URLS', 'false')
        allow(entry).to receive(:value_for).with(:image_url).and_return('https://foobar.x/images/ci/gitlab-ci-cd-logo_2x.png')
        allow(entry).to receive(:value_for).with(:documentation_link).and_return('')

        subject.valid?

        expect(subject.errors[:documentation_link]).to include(/must be a valid URL/)
        expect(subject.errors[:image_url]).to include(/is blocked: Host cannot be resolved or invalid/)
      end

      it 'validates published_at is a date' do
        allow(entry).to receive(:published_at).and_return('christmas day')

        subject.valid?

        expect(subject.errors[:published_at]).to include(/must be valid Date/)
      end

      it 'validates available_in are included in list' do
        allow(entry).to receive(:available_in).and_return(['ALL'])

        subject.valid?

        expect(subject.errors[:available_in].first).to include("must be one of", "Free", "Premium", "Ultimate")
      end
    end
  end
end
