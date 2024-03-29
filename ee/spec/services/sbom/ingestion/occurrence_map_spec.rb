# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::OccurrenceMap, feature_category: :dependency_management do
  let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component) }
  let_it_be(:report_source) { build_stubbed(:ci_reports_sbom_source) }

  let(:vulnerability_info) { create(:sbom_vulnerabilities) }
  let(:base_data) do
    {
      component_id: nil,
      component_type: report_component.component_type,
      component_version_id: nil,
      name: report_component.name,
      purl_type: report_component.purl.type,
      source: report_source.data,
      source_id: nil,
      source_type: report_source.source_type,
      version: report_component.version
    }
  end

  subject(:occurrence_map) { described_class.new(report_component, report_source, vulnerability_info) }

  describe '#to_h' do
    it 'returns a hash with base data without ids assigned' do
      expect(occurrence_map.to_h).to eq(base_data)
    end

    context 'when ids are assigned' do
      let(:ids) do
        {
          component_id: 1,
          component_version_id: 2,
          source_id: 3
        }
      end

      before do
        occurrence_map.component_id = ids[:component_id]
        occurrence_map.component_version_id = ids[:component_version_id]
        occurrence_map.source_id = ids[:source_id]
      end

      it 'returns a hash with ids and base data' do
        expect(occurrence_map.to_h).to eq(base_data.merge(ids))
      end
    end

    context 'when there is no source' do
      let(:report_source) { nil }

      it 'returns a hash without source information' do
        expect(occurrence_map.to_h).to eq(
          {
            component_id: nil,
            component_type: report_component.component_type,
            component_version_id: nil,
            purl_type: report_component.purl.type,
            name: report_component.name,
            source: nil,
            source_id: nil,
            source_type: nil,
            version: report_component.version
          }
        )
      end
    end

    context 'when component has no purl' do
      let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, purl: nil) }

      it 'returns a hash with a nil purl_type' do
        expect(occurrence_map.to_h).to eq(
          {
            component_id: nil,
            component_type: report_component.component_type,
            component_version_id: nil,
            name: report_component.name,
            purl_type: nil,
            source: report_source.data,
            source_id: nil,
            source_type: report_source.source_type,
            version: report_component.version
          }
        )
      end
    end

    context 'when component has namespace' do
      let_it_be(:report_component) do
        build_stubbed(:ci_reports_sbom_component, namespace: 'org.apache.tomcat',
          name: 'tomcat-catalina', purl_type: 'maven')
      end

      it 'returns a hash with name attribute having both namespace and name' do
        expect(occurrence_map.to_h).to eq(
          {
            component_id: nil,
            component_type: report_component.component_type,
            component_version_id: nil,
            name: 'org.apache.tomcat/tomcat-catalina',
            purl_type: 'maven',
            source: report_source.data,
            source_id: nil,
            source_type: report_source.source_type,
            version: report_component.version
          }
        )
      end
    end

    describe 'normalization' do
      using RSpec::Parameterized::TableSyntax

      let(:report_component) { build_stubbed(:ci_reports_sbom_component, purl_type: purl_type, name: name) }

      where(:purl_type, :name, :expected) do
        :npm  | 'Cookie_Parser'            | 'Cookie_Parser'
        :pypi | 'Flask_SQLAlchemy'         | 'flask-sqlalchemy'
      end

      with_them do
        it 'outputs normalized name' do
          expect(occurrence_map.to_h[:name]).to eq(expected)
        end
      end

      context 'when purl is absent' do
        let(:name) { 'EnterpriseLibrary_Common' }
        let(:report_component) { build_stubbed(:ci_reports_sbom_component, purl: nil, name: name) }

        it 'does not perform normalization' do
          expect(occurrence_map.to_h[:name]).to eq(name)
        end
      end
    end
  end

  describe '#version_present?' do
    it 'returns true when a version is present' do
      expect(occurrence_map.version_present?).to be(true)
    end

    context 'when version is empty' do
      let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, version: '') }

      specify { expect(occurrence_map.version_present?).to be(false) }
    end

    context 'when version is absent' do
      let_it_be(:report_component) { build_stubbed(:ci_reports_sbom_component, version: nil) }

      it { expect(occurrence_map.version_present?).to be(false) }
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:packager).to(:report_source).allow_nil }
    it { is_expected.to delegate_method(:input_file_path).to(:report_source).allow_nil }
    it { is_expected.to delegate_method(:name).to(:report_component) }
    it { is_expected.to delegate_method(:version).to(:report_component) }
  end

  context 'without vulnerability data' do
    it { expect(occurrence_map.vulnerability_ids).to be_empty }
    it { expect(occurrence_map.vulnerability_count).to be_zero }
    it { expect(occurrence_map.highest_severity).to be_nil }
  end

  context 'with vulnerability data' do
    let(:pipeline) { vulnerability_info.pipeline }
    let(:finding) do
      create(
        :vulnerabilities_finding,
        :detected,
        :with_dependency_scanning_metadata,
        project: pipeline.project,
        file: occurrence_map.input_file_path,
        package: occurrence_map.name,
        version: occurrence_map.version
      )
    end

    before do
      create(:vulnerabilities_finding_pipeline, pipeline: pipeline, finding: finding)
    end

    it { expect(occurrence_map.vulnerability_ids).to eq([finding.vulnerability_id]) }
    it { expect(occurrence_map.vulnerability_count).to be 1 }
    it { expect(occurrence_map.highest_severity).to eq 'high' }
  end
end
