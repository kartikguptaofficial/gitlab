# frozen_string_literal: true

module Sbom
  class DependenciesFinder
    def initialize(project_or_group, params: {})
      @project_or_group = project_or_group
      @params = params
    end

    def execute
      sbom_occurrences = filtered_collection

      case params[:sort_by]
      when 'name'
        sbom_occurrences.order_by_component_name(params[:sort])
      when 'packager'
        sbom_occurrences.order_by_package_name(params[:sort])
      else
        sbom_occurrences.order_by_id
      end.paginate(params[:per_page].to_i, params[:page].to_i)
    end

    private

    attr_reader :project_or_group, :params

    def filtered_collection
      collection = project_or_group.sbom_occurrences

      collection = filter_by_package_managers(collection) if params[:package_managers].present?

      collection = filter_by_component_names(collection) if params[:component_names].present?

      collection
    end

    def filter_by_package_managers(sbom_occurrences)
      sbom_occurrences.filter_by_package_managers(params[:package_managers])
    end

    def filter_by_component_names(sbom_occurrences)
      sbom_occurrences.filter_by_component_names(params[:component_names])
    end
  end
end
