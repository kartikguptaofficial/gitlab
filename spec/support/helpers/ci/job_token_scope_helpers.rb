# frozen_string_literal: true

module Ci
  module JobTokenScopeHelpers
    def create_project_in_allowlist(root_project, direction:, target_project: nil)
      included_project = target_project || create(:project)
      create(
        :ci_job_token_project_scope_link,
        source_project: root_project,
        target_project: included_project,
        direction: direction
      )

      included_project
    end

    def create_project_in_both_allowlists(root_project)
      create_project_in_allowlist(root_project, direction: :outbound).tap do |new_project|
        create_project_in_allowlist(root_project, target_project: new_project, direction: :inbound)
      end
    end

    def create_inbound_accessible_project(project)
      create(:project).tap do |accessible_project|
        add_inbound_accessible_linkage(project, accessible_project)
      end
    end

    def create_inbound_and_outbound_accessible_project(project)
      create(:project).tap do |accessible_project|
        make_project_fully_accessible(project, accessible_project)
      end
    end

    def make_project_fully_accessible(project, accessible_project)
      add_outbound_accessible_linkage(project, accessible_project)
      add_inbound_accessible_linkage(project, accessible_project)
    end

    def add_outbound_accessible_linkage(project, accessible_project)
      create(
        :ci_job_token_project_scope_link,
        source_project: project,
        target_project: accessible_project,
        direction: :outbound
      )
    end

    def add_inbound_accessible_linkage(project, accessible_project)
      create(
        :ci_job_token_project_scope_link,
        source_project: accessible_project,
        target_project: project,
        direction: :inbound
      )
    end
  end
end
