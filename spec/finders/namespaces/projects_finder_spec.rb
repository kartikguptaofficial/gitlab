# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::ProjectsFinder do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:namespace) { create(:group, :public) }
  let_it_be(:subgroup) { create(:group, parent: namespace) }
  let_it_be(:project_1) { create(:project, :public, group: namespace, path: 'project', name: 'Project') }
  let_it_be(:project_2) { create(:project, :public, group: namespace, path: 'test-project', name: 'Test Project') }
  let_it_be(:project_3) { create(:project, :public, :issues_disabled, path: 'sub-test-project', group: subgroup, name: 'Sub Test Project') }
  let_it_be(:project_4) { create(:project, :public, :merge_requests_disabled, path: 'test-project-2', group: namespace, name: 'Test Project 2') }

  let(:params) { {} }

  let(:finder) { described_class.new(namespace: namespace, params: params, current_user: current_user) }

  subject(:projects) { finder.execute }

  describe '#execute' do
    context 'without a namespace' do
      let(:namespace) { nil }

      it 'returns an empty array' do
        expect(projects).to be_empty
      end
    end

    context 'with a namespace' do
      it 'returns the project for the namespace' do
        expect(projects).to contain_exactly(project_1, project_2, project_4)
      end

      context 'when include_subgroups is provided' do
        let(:params) { { include_subgroups: true } }

        it 'returns all projects for the namespace' do
          expect(projects).to contain_exactly(project_1, project_2, project_3, project_4)
        end

        context 'when ids are provided' do
          let(:params) { { include_subgroups: true, ids: [project_3.id] } }

          it 'returns all projects for the ids' do
            expect(projects).to contain_exactly(project_3)
          end
        end
      end

      context 'when ids are provided' do
        let(:params) { { ids: [project_1.id] } }

        it 'returns all projects for the ids' do
          expect(projects).to contain_exactly(project_1)
        end
      end

      context 'when with_issues_enabled is true' do
        let(:params) { { with_issues_enabled: true, include_subgroups: true } }

        it 'returns the projects that have issues enabled' do
          expect(projects).to contain_exactly(project_1, project_2, project_4)
        end
      end

      context 'when with_merge_requests_enabled is true' do
        let(:params) { { with_merge_requests_enabled: true } }

        it 'returns the projects that have merge requests enabled' do
          expect(projects).to contain_exactly(project_1, project_2)
        end
      end

      context 'when sort is similarity' do
        let(:params) { { sort: :similarity, search: 'test' } }

        it 'returns projects by similarity' do
          expect(projects).to contain_exactly(project_2, project_4)
        end
      end

      context 'when search parameter is missing' do
        let(:params) { { sort: :similarity } }

        it 'returns all projects' do
          expect(projects).to contain_exactly(project_1, project_2, project_4)
        end
      end

      context 'when sort parameter is missing' do
        let(:params) { { search: 'test' } }

        it 'returns matching projects' do
          expect(projects).to contain_exactly(project_2, project_4)
        end
      end

      context 'when sort parameter is ACTIVITY_DESC' do
        let(:params) { { sort: :latest_activity_desc } }

        before do
          project_2.update!(last_activity_at: 10.minutes.ago)
          project_1.update!(last_activity_at: 5.minutes.ago)
          project_4.update!(last_activity_at: 1.minute.ago)
        end

        it 'returns projects sorted by latest activity' do
          expect(projects).to eq([project_4, project_1, project_2])
        end
      end
    end
  end
end
