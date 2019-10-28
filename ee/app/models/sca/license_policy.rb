# frozen_string_literal: true

module SCA
  class LicensePolicy
    attr_reader :id, :name, :url, :dependencies, :spdx_identifier, :classification

    def initialize(reported_license, software_policy)
      @id = software_policy&.id
      @name = software_policy&.name || reported_license.name
      @url = reported_license&.url
      @dependencies = reported_license&.dependencies || []
      @spdx_identifier = software_policy&.spdx_identifier || reported_license.id
      @classification = classify(software_policy)
    end

    private

    def classify(policy)
      return 'allowed' if policy&.approved?
      return 'denied' if policy&.blacklisted?

      'unclassified'
    end
  end
end
