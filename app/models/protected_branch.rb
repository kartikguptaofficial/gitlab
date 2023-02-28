# frozen_string_literal: true

class ProtectedBranch < ApplicationRecord
  include ProtectedRef
  include Gitlab::SQL::Pattern
  include FromUnion

  belongs_to :group, foreign_key: :namespace_id, touch: true, inverse_of: :protected_branches

  validate :validate_either_project_or_top_group

  scope :requiring_code_owner_approval, -> { where(code_owner_approval_required: true) }
  scope :allowing_force_push, -> { where(allow_force_push: true) }
  scope :sorted_by_name, -> { order(name: :asc) }
  scope :sorted_by_namespace_and_name, -> { order(:namespace_id, :name) }

  scope :for_group, ->(group) { where(group: group) }

  protected_ref_access_levels :merge, :push

  def self.get_ids_by_name(name)
    where(name: name).pluck(:id)
  end

  def self.protected_ref_accessible_to?(ref, user, project:, action:, protected_refs: nil)
    # Maintainers, owners and admins are allowed to create the default branch

    if project.empty_repo? && project.default_branch_protected?
      return true if user.admin? || project.team.max_member_access(user.id) > Gitlab::Access::DEVELOPER
    end

    super
  end

  # Check if branch name is marked as protected in the system
  def self.protected?(project, ref_name)
    return true if project.empty_repo? && project.default_branch_protected?
    return false if ref_name.blank?

    ProtectedBranches::CacheService.new(project).fetch(ref_name) do # rubocop: disable CodeReuse/ServiceClass
      self.matching(ref_name, protected_refs: protected_refs(project)).present?
    end
  end

  def self.allow_force_push?(project, ref_name)
    if Feature.enabled?(:group_protected_branches)
      protected_branches = project.all_protected_branches.matching(ref_name)

      project_protected_branches, group_protected_branches = protected_branches.partition(&:project_id)

      # Group owner can be able to enforce the settings
      return group_protected_branches.any?(&:allow_force_push) if group_protected_branches.present?
      return project_protected_branches.any?(&:allow_force_push) if project_protected_branches.present?

      false
    else
      project.protected_branches.allowing_force_push.matching(ref_name).any?
    end
  end

  def self.any_protected?(project, ref_names)
    protected_refs(project).any? do |protected_ref|
      ref_names.any? do |ref_name|
        protected_ref.matches?(ref_name)
      end
    end
  end

  def self.protected_refs(project)
    if Feature.enabled?(:group_protected_branches)
      project.all_protected_branches
    else
      project.protected_branches
    end
  end

  # overridden in EE
  def self.branch_requires_code_owner_approval?(project, branch_name)
    false
  end

  def self.by_name(query)
    return none if query.blank?

    where(fuzzy_arel_match(:name, query.downcase))
  end

  def allow_multiple?(type)
    type == :push
  end

  def self.downcase_humanized_name
    name.underscore.humanize.downcase
  end

  def default_branch?
    name == project.default_branch
  end

  def group_level?
    entity.is_a?(Group)
  end

  def project_level?
    entity.is_a?(Project)
  end

  def entity
    group || project
  end

  private

  def validate_either_project_or_top_group
    if !project && !group
      errors.add(:base, _('must be associated with a Group or a Project'))
    elsif project && group
      errors.add(:base, _('cannot be associated with both a Group and a Project'))
    elsif group && group.subgroup?
      errors.add(:base, _('cannot be associated with a subgroup'))
    end
  end
end

ProtectedBranch.prepend_mod_with('ProtectedBranch')
