# frozen_string_literal: true

module Sbom
  module Ingestion
    class IngestReportsService
      def self.execute(pipeline)
        new(pipeline).execute
      end

      def initialize(pipeline)
        @pipeline = pipeline
      end

      def execute
        ingest_reports.then { |ingested_ids| delete_not_present_occurrences(ingested_ids) }

        project.set_latest_ingested_sbom_pipeline_id(pipeline.id)
      end

      private

      attr_reader :pipeline

      delegate :project, to: :pipeline, private: true

      def ingest_reports
        sbom_reports.select(&:valid?).flat_map { |report| ingest_report(report) }
      end

      def sbom_reports
        pipeline.sbom_reports.reports
      end

      def ingest_report(sbom_report)
        IngestReportService.execute(pipeline, sbom_report, vulnerabilities_info)
      end

      def delete_not_present_occurrences(ingested_occurrence_ids)
        DeleteNotPresentOccurrencesService.execute(pipeline, ingested_occurrence_ids)
      end

      def vulnerabilities_info
        @vulnerabilities_info ||= Sbom::Ingestion::Vulnerabilities.new(pipeline)
      end
    end
  end
end
