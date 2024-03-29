# frozen_string_literal: true

module ProtectedBranches
  class BaseService < ::BaseService
    attr_reader :project_or_group

    # current_user - The user that performs the action
    # params - A hash of parameters
    def initialize(project_or_group, current_user = nil, params = {})
      @project_or_group = project_or_group
      @current_user = current_user
      @params = params
    end

    def after_execute(*)
      # overridden in EE::ProtectedBranches module
    end

    def refresh_cache
      CacheService.new(@project_or_group, @current_user, @params).refresh
      refresh_cache_for_groups_projects
    rescue StandardError => e
      Gitlab::ErrorTracking.track_exception(e)
    end

    private

    def refresh_cache_for_groups_projects
      return unless @project_or_group.is_a?(Group)

      @project_or_group.all_projects.find_each do |project|
        CacheService.new(project, @current_user, @params).refresh
      end
    end
  end
end

ProtectedBranches::BaseService.prepend_mod
