require 'spec_helper'

describe ProtectedBranch do
  subject { build_stubbed(:protected_branch) }

  describe 'Associations' do
    it { is_expected.to belong_to(:project) }
  end

  describe "Uniqueness validations" do
    [ProtectedBranch::MergeAccessLevel, ProtectedBranch::PushAccessLevel].each do |access_level_class|
      let(:user) { create(:user) }
      let(:factory_name) { access_level_class.to_s.underscore.sub('/', '_').to_sym }
      let(:association_name) { access_level_class.to_s.underscore.sub('protected_branch/', '').pluralize.to_sym }
      human_association_name = access_level_class.to_s.underscore.humanize.sub('Protected branch/', '')

      context "while checking uniqueness of a role-based #{human_association_name}" do
        it "allows a single #{human_association_name} for a role (per protected branch)" do
          first_protected_branch = create(:protected_branch, default_access_level: false)
          second_protected_branch = create(:protected_branch, default_access_level: false)

          first_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MASTER)
          second_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MASTER)

          expect(first_protected_branch).to be_valid
          expect(second_protected_branch).to be_valid

          first_protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MASTER)
          expect(first_protected_branch).to be_invalid
          expect(first_protected_branch.errors.full_messages.first).to match("access level has already been taken")
        end

        it "does not count a user-based #{human_association_name} with an `access_level` set" do
          protected_branch = create(:protected_branch, default_access_level: false)

          protected_branch.send(association_name) << build(factory_name, user: user, access_level: Gitlab::Access::MASTER)
          protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MASTER)

          expect(protected_branch).to be_valid
        end

        it "does not count a group-based #{human_association_name} with an `access_level` set" do
          group = create(:group)
          protected_branch = create(:protected_branch, default_access_level: false)

          protected_branch.send(association_name) << build(factory_name, group: group, access_level: Gitlab::Access::MASTER)
          protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MASTER)

          expect(protected_branch).to be_valid
        end
      end

      context "while checking uniqueness of a user-based #{human_association_name}" do
        it "allows a single #{human_association_name} for a user (per protected branch)" do
          first_protected_branch = create(:protected_branch, default_access_level: false)
          second_protected_branch = create(:protected_branch, default_access_level: false)

          first_protected_branch.send(association_name) << build(factory_name, user: user)
          second_protected_branch.send(association_name) << build(factory_name, user: user)

          expect(first_protected_branch).to be_valid
          expect(second_protected_branch).to be_valid

          first_protected_branch.send(association_name) << build(factory_name, user: user)
          expect(first_protected_branch).to be_invalid
          expect(first_protected_branch.errors.full_messages.first).to match("user has already been taken")
        end

        it "ignores the `access_level` while validating a user-based #{human_association_name}" do
          protected_branch = create(:protected_branch, default_access_level: false)

          protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MASTER)
          protected_branch.send(association_name) << build(factory_name, user: user, access_level: Gitlab::Access::MASTER)

          expect(protected_branch).to be_valid
        end
      end

      context "while checking uniqueness of a group-based #{human_association_name}" do
        let(:group) { create(:group) }

        it "allows a single #{human_association_name} for a group (per protected branch)" do
          first_protected_branch = create(:protected_branch, default_access_level: false)
          second_protected_branch = create(:protected_branch, default_access_level: false)

          first_protected_branch.send(association_name) << build(factory_name, group: group)
          second_protected_branch.send(association_name) << build(factory_name, group: group)

          expect(first_protected_branch).to be_valid
          expect(second_protected_branch).to be_valid

          first_protected_branch.send(association_name) << build(factory_name, group: group)
          expect(first_protected_branch).to be_invalid
          expect(first_protected_branch.errors.full_messages.first).to match("group has already been taken")
        end

        it "ignores the `access_level` while validating a group-based #{human_association_name}" do
          protected_branch = create(:protected_branch, default_access_level: false)

          protected_branch.send(association_name) << build(factory_name, access_level: Gitlab::Access::MASTER)
          protected_branch.send(association_name) << build(factory_name, group: group, access_level: Gitlab::Access::MASTER)

          expect(protected_branch).to be_valid
        end
      end
    end
  end

  describe 'Validation' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:name) }
  end

  describe "#matches?" do
    context "when the protected branch setting is not a wildcard" do
      let(:protected_branch) { build(:protected_branch, name: "production/some-branch") }

      it "returns true for branch names that are an exact match" do
        expect(protected_branch.matches?("production/some-branch")).to be true
      end

      it "returns false for branch names that are not an exact match" do
        expect(protected_branch.matches?("staging/some-branch")).to be false
      end
    end

    context "when the protected branch name contains wildcard(s)" do
      context "when there is a single '*'" do
        let(:protected_branch) { build(:protected_branch, name: "production/*") }

        it "returns true for branch names matching the wildcard" do
          expect(protected_branch.matches?("production/some-branch")).to be true
          expect(protected_branch.matches?("production/")).to be true
        end

        it "returns false for branch names not matching the wildcard" do
          expect(protected_branch.matches?("staging/some-branch")).to be false
          expect(protected_branch.matches?("production")).to be false
        end
      end

      context "when the wildcard contains regex symbols other than a '*'" do
        let(:protected_branch) { build(:protected_branch, name: "pro.duc.tion/*") }

        it "returns true for branch names matching the wildcard" do
          expect(protected_branch.matches?("pro.duc.tion/some-branch")).to be true
        end

        it "returns false for branch names not matching the wildcard" do
          expect(protected_branch.matches?("production/some-branch")).to be false
          expect(protected_branch.matches?("proXducYtion/some-branch")).to be false
        end
      end

      context "when there are '*'s at either end" do
        let(:protected_branch) { build(:protected_branch, name: "*/production/*") }

        it "returns true for branch names matching the wildcard" do
          expect(protected_branch.matches?("gitlab/production/some-branch")).to be true
          expect(protected_branch.matches?("/production/some-branch")).to be true
          expect(protected_branch.matches?("gitlab/production/")).to be true
          expect(protected_branch.matches?("/production/")).to be true
        end

        it "returns false for branch names not matching the wildcard" do
          expect(protected_branch.matches?("gitlabproductionsome-branch")).to be false
          expect(protected_branch.matches?("production/some-branch")).to be false
          expect(protected_branch.matches?("gitlab/production")).to be false
          expect(protected_branch.matches?("production")).to be false
        end
      end

      context "when there are arbitrarily placed '*'s" do
        let(:protected_branch) { build(:protected_branch, name: "pro*duction/*/gitlab/*") }

        it "returns true for branch names matching the wildcard" do
          expect(protected_branch.matches?("production/some-branch/gitlab/second-branch")).to be true
          expect(protected_branch.matches?("proXYZduction/some-branch/gitlab/second-branch")).to be true
          expect(protected_branch.matches?("proXYZduction/gitlab/gitlab/gitlab")).to be true
          expect(protected_branch.matches?("proXYZduction//gitlab/")).to be true
          expect(protected_branch.matches?("proXYZduction/some-branch/gitlab/")).to be true
          expect(protected_branch.matches?("proXYZduction//gitlab/some-branch")).to be true
        end

        it "returns false for branch names not matching the wildcard" do
          expect(protected_branch.matches?("production/some-branch/not-gitlab/second-branch")).to be false
          expect(protected_branch.matches?("prodXYZuction/some-branch/gitlab/second-branch")).to be false
          expect(protected_branch.matches?("proXYZduction/gitlab/some-branch/gitlab")).to be false
          expect(protected_branch.matches?("proXYZduction/gitlab//")).to be false
          expect(protected_branch.matches?("proXYZduction/gitlab/")).to be false
          expect(protected_branch.matches?("proXYZduction//some-branch/gitlab")).to be false
        end
      end
    end
  end

  describe "#matching" do
    context "for direct matches" do
      it "returns a list of protected branches matching the given branch name" do
        production = create(:protected_branch, name: "production")
        staging = create(:protected_branch, name: "staging")

        expect(described_class.matching("production")).to include(production)
        expect(described_class.matching("production")).not_to include(staging)
      end

      it "accepts a list of protected branches to search from, so as to avoid a DB call" do
        production = build(:protected_branch, name: "production")
        staging = build(:protected_branch, name: "staging")

        expect(described_class.matching("production")).to be_empty
        expect(described_class.matching("production", protected_refs: [production, staging])).to include(production)
        expect(described_class.matching("production", protected_refs: [production, staging])).not_to include(staging)
      end
    end

    context "for wildcard matches" do
      it "returns a list of protected branches matching the given branch name" do
        production = create(:protected_branch, name: "production/*")
        staging = create(:protected_branch, name: "staging/*")

        expect(described_class.matching("production/some-branch")).to include(production)
        expect(described_class.matching("production/some-branch")).not_to include(staging)
      end

      it "accepts a list of protected branches to search from, so as to avoid a DB call" do
        production = build(:protected_branch, name: "production/*")
        staging = build(:protected_branch, name: "staging/*")

        expect(described_class.matching("production/some-branch")).to be_empty
        expect(described_class.matching("production/some-branch", protected_refs: [production, staging])).to include(production)
        expect(described_class.matching("production/some-branch", protected_refs: [production, staging])).not_to include(staging)
      end
    end
  end

  describe '#protected?' do
    context 'existing project' do
      let(:project) { create(:project, :repository) }

      it 'returns true when the branch matches a protected branch via direct match' do
        create(:protected_branch, project: project, name: "foo")

        expect(described_class.protected?(project, 'foo')).to eq(true)
      end

      it 'returns true when the branch matches a protected branch via wildcard match' do
        create(:protected_branch, project: project, name: "production/*")

        expect(described_class.protected?(project, 'production/some-branch')).to eq(true)
      end

      it 'returns false when the branch does not match a protected branch via direct match' do
        expect(described_class.protected?(project, 'foo')).to eq(false)
      end

      it 'returns false when the branch does not match a protected branch via wildcard match' do
        create(:protected_branch, project: project, name: "production/*")

        expect(described_class.protected?(project, 'staging/some-branch')).to eq(false)
      end
    end

    context "new project" do
      let(:project) { create(:empty_project) }

      it 'returns false when default_protected_branch is unprotected' do
        stub_application_setting(default_branch_protection: Gitlab::Access::PROTECTION_NONE)

        expect(described_class.protected?(project, 'master')).to be false
      end

      it 'returns false when default_protected_branch lets developers push' do
        stub_application_setting(default_branch_protection: Gitlab::Access::PROTECTION_DEV_CAN_PUSH)

        expect(described_class.protected?(project, 'master')).to be false
      end

      it 'returns true when default_branch_protection does not let developers push but let developer merge branches' do
        stub_application_setting(default_branch_protection: Gitlab::Access::PROTECTION_DEV_CAN_MERGE)

        expect(described_class.protected?(project, 'master')).to be true
      end

      it 'returns true when default_branch_protection is in full protection' do
        stub_application_setting(default_branch_protection: Gitlab::Access::PROTECTION_FULL)

        expect(described_class.protected?(project, 'master')).to be true
      end
    end
  end
end
