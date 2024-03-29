# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberRoles::RolesFinder, feature_category: :system_access do
  let(:params) { { parent: group } }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be(:member_role_1) { create(:member_role, name: 'Tester', namespace: group) }
  let_it_be(:member_role_2) { create(:member_role, name: 'Manager', namespace: group) }
  let_it_be(:member_role_instance) { create(:member_role, :instance) }
  let_it_be(:group_2_member_role) { create(:member_role, name: 'Another role') }
  let_it_be(:active_group_iterations_cadence) do
    create(:iterations_cadence, group: group, active: true, duration_in_weeks: 1, title: 'one week iterations')
  end

  let(:current_user) { user }

  subject(:find_member_roles) { described_class.new(current_user, params).execute }

  context 'without permissions' do
    context 'when filtering by group' do
      it 'does not return any member roles for group' do
        expect(find_member_roles).to be_empty
      end
    end

    context 'when filtering by id' do
      let(:params) { { id: member_role_2.id } }

      it 'does not return any member roles for id' do
        expect(find_member_roles).to be_empty
      end
    end
  end

  context 'with permissions' do
    before_all do
      group.add_owner(user)
    end

    context 'without custom roles feature' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it 'does not return any member roles for group' do
        expect(find_member_roles).to be_empty
      end
    end

    context 'with custom roles feature' do
      before do
        stub_licensed_features(custom_roles: true)
      end

      context 'when filter param is missing' do
        let(:params) { {} }

        it 'raises an error' do
          expect { find_member_roles }.to raise_error { ArgumentError }
        end
      end

      context 'when filtering by group' do
        it 'returns all member roles of the group' do
          expect(find_member_roles).to eq([member_role_2, member_role_1])
        end
      end

      context 'when filtering by project' do
        let(:params) { { parent: project } }

        it 'returns all member roles of the project root ancestor' do
          expect(find_member_roles).to eq([member_role_2, member_role_1])
        end
      end

      context 'when filtering by id' do
        let(:params) { { id: member_role_2.id } }

        it 'returns member role found by id' do
          expect(find_member_roles).to eq([member_role_2])
        end
      end

      context 'when filtering by multiple ids' do
        let(:params) { { id: [member_role_1.id, member_role_2.id, group_2_member_role.id] } }

        it 'returns only member roles a user can read' do
          expect(find_member_roles).to eq([member_role_2, member_role_1])
        end

        context 'when a user is an instance admin', :enable_admin_mode do
          let(:current_user) { admin }

          it 'returns all requested member roles for the instance admin' do
            expect(find_member_roles).to eq([group_2_member_role, member_role_2, member_role_1])
          end
        end
      end

      context 'when requesting roles for the whole instance' do
        let(:params) { { instance_roles: true } }

        it 'raises an error' do
          expect { find_member_roles }.to raise_error { ArgumentError }
        end

        context 'when a user is an instance admin', :enable_admin_mode do
          let(:current_user) { admin }

          it 'returns instance member roles for instance admin' do
            expect(find_member_roles).to eq([member_role_instance])
          end
        end
      end
    end
  end
end
