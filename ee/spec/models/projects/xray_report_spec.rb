# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::XrayReport, feature_category: :code_suggestions do
  let_it_be(:project) { create(:project) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:lang) }
    it { is_expected.to validate_presence_of(:payload) }
    it { is_expected.to validate_presence_of(:file_checksum) }

    it 'validates uniqueness of lang and project', :aggregate_failures do
      create(:xray_report, project: project, lang: 'Ruby')
      expect(build(:xray_report, lang: 'Ruby')).to be_valid
      expect(build(:xray_report, project: project, lang: 'Go')).to be_valid
      expect(build(:xray_report, project: project, lang: 'Ruby')).not_to be_valid
    end
  end

  describe 'scopes' do
    let_it_be(:xray_report_ruby) { create(:xray_report, lang: 'Ruby') }
    let_it_be(:xray_report) { create(:xray_report, project: project, lang: 'Python') }

    it '.for_lang' do
      expect(described_class.for_lang('Ruby')).to contain_exactly(xray_report_ruby)
    end

    it '.for_project' do
      expect(described_class.for_project(project)).to contain_exactly(xray_report)
    end
  end

  describe '#libs' do
    context 'with libs in payload' do
      let(:payload) { { 'libs' => %w[foo bar] } }

      it 'returns libs from payload' do
        expect(described_class.new(payload: payload).libs).to eq(payload['libs'])
      end
    end

    context 'without libs in payload' do
      let(:payload) { {} }

      it 'returns empty array' do
        expect(described_class.new(payload: payload).libs).to eq([])
      end
    end
  end
end
