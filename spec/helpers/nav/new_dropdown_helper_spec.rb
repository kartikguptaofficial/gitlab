# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nav::NewDropdownHelper, feature_category: :navigation do
  describe '#new_dropdown_view_model' do
    let(:user) { build_stubbed(:user) }
    let(:current_user) { user }
    let(:current_project) { nil }
    let(:current_group) { nil }
    let(:with_can_create_project) { false }
    let(:with_can_create_group) { false }
    let(:with_can_create_snippet) { false }
    let(:with_context) { true }
    let(:title) { 'Create new...' }

    subject(:view_model) do
      helper.new_dropdown_view_model(project: current_project, group: current_group, with_context: with_context)
    end

    before do
      allow(helper).to receive(:current_user) { current_user }
      allow(helper).to receive(:can?).and_return(false)
      allow(user).to receive(:can_create_project?) { with_can_create_project }
      allow(user).to receive(:can_create_group?) { with_can_create_group }
      allow(user).to receive(:can?).with(:create_snippet) { with_can_create_snippet }
    end

    shared_examples 'invite member item' do |partial|
      it 'shows invite member link with emoji' do
        expect(view_model[:menu_sections]).to eq(
          expected_menu_section(
            title: expected_title,
            menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
              id: 'invite',
              title: 'Invite members',
              icon: 'shaking_hands',
              href: expected_href,
              partial: partial,
              data: {
                track_action: 'click_link_invite_members',
                track_label: 'plus_menu_dropdown',
                track_property: 'navigation_top'
              }
            )
          )
        )
      end
    end

    it 'has title' do
      expect(view_model[:title]).to eq('Create new...')
    end

    context 'when current_user is nil (anonymous)' do
      let(:current_user) { nil }

      it { is_expected.to be_nil }
    end

    context 'when group and project are nil' do
      it 'has base results' do
        results = {
          title: title,
          menu_sections: []
        }

        expect(view_model).to eq(results)
      end

      context 'when can create project' do
        let(:with_can_create_project) { true }

        it 'has project menu item' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: _('In GitLab'),
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'general_new_project',
                title: 'New project/repository',
                href: '/projects/new',
                data: {
                  track_action: 'click_link_new_project',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top',
                  qa_selector: 'global_new_project_link'
                }
              )
            )
          )
        end
      end

      context 'when can create group' do
        let(:with_can_create_group) { true }

        it 'has group menu item' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: _('In GitLab'),
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'general_new_group',
                title: 'New group',
                href: '/groups/new',
                data: {
                  track_action: 'click_link_new_group',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top',
                  qa_selector: 'global_new_group_link'
                }
              )
            )
          )
        end
      end

      context 'when can create snippet' do
        let(:with_can_create_snippet) { true }

        it 'has new snippet menu item' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: _('In GitLab'),
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'general_new_snippet',
                title: 'New snippet',
                href: '/-/snippets/new',
                data: {
                  track_action: 'click_link_new_snippet_parent',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top',
                  qa_selector: 'global_new_snippet_link'
                }
              )
            )
          )
        end
      end
    end

    context 'with persisted group' do
      let(:group) { build_stubbed(:group) }
      let(:current_group) { group }
      let(:with_can_create_projects_in_group) { false }
      let(:with_can_create_subgroup_in_group) { false }
      let(:with_can_admin_in_group) { false }

      before do
        allow(group).to receive(:persisted?).and_return(true)
        allow(helper)
          .to receive(:can?).with(current_user, :create_projects, group) { with_can_create_projects_in_group }
        allow(helper)
          .to receive(:can?).with(current_user, :create_subgroup, group) { with_can_create_subgroup_in_group }
        allow(helper)
          .to receive(:can?).with(current_user, :admin_group_member, group) { with_can_admin_in_group }
      end

      it 'has base results' do
        results = {
          title: title,
          menu_sections: [],
          context: group
        }

        expect(view_model).to eq(results)
      end

      context 'without context' do
        let(:with_context) { false }

        it 'has base results' do
          results = {
            title: title,
            menu_sections: []
          }

          expect(view_model).to eq(results)
        end
      end

      context 'when can create projects in group' do
        let(:with_can_create_projects_in_group) { true }

        it 'has new project menu item' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: 'In this group',
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'new_project',
                title: 'New project/repository',
                href: "/projects/new?namespace_id=#{group.id}",
                data: {
                  track_action: 'click_link_new_project_group',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top'
                }
              )
            )
          )
        end
      end

      context 'when can create subgroup' do
        let(:with_can_create_subgroup_in_group) { true }

        it 'has new subgroup menu item' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: 'In this group',
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'new_subgroup',
                title: 'New subgroup',
                href: "/groups/new?parent_id=#{group.id}#create-group-pane",
                data: {
                  track_action: 'click_link_new_subgroup',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top'
                }
              )
            )
          )
        end
      end

      context 'when can invite members' do
        let(:with_can_admin_in_group) { true }
        let(:with_invite_members_experiment) { true }
        let(:expected_title) { 'In this group' }
        let(:expected_href) { "/groups/#{group.full_path}/-/group_members" }

        it_behaves_like 'invite member item', 'groups/invite_members_top_nav_link'
      end
    end

    context 'with persisted project' do
      let(:project) { build_stubbed(:project) }
      let(:merge_project) { build_stubbed(:project) }
      let(:current_project) { project }
      let(:with_show_new_issue_link) { false }
      let(:with_merge_project) { nil }
      let(:with_can_create_snippet_in_project) { false }
      let(:with_can_admin_project_member) { false }

      before do
        allow(helper).to receive(:show_new_issue_link?).with(project) { with_show_new_issue_link }
        allow(helper).to receive(:merge_request_source_project_for_project).with(project) { with_merge_project }
        allow(helper).to receive(:can?).with(user, :create_snippet, project) { with_can_create_snippet_in_project }
        allow(helper).to receive(:can_admin_project_member?) { with_can_admin_project_member }
      end

      it 'has base results with context' do
        results = {
          title: title,
          menu_sections: [],
          context: project
        }

        expect(view_model).to eq(results)
      end

      context 'without context' do
        let(:with_context) { false }

        it 'has base results without context' do
          results = {
            title: title,
            menu_sections: []
          }

          expect(view_model).to eq(results)
        end
      end

      context 'with show_new_issue_link?' do
        let(:with_show_new_issue_link) { true }

        it 'shows new issue menu item' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: 'In this project',
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'new_issue',
                title: 'New issue',
                href: "/#{project.path_with_namespace}/-/issues/new",
                data: {
                  track_action: 'click_link_new_issue',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top',
                  qa_selector: 'new_issue_link'
                }
              )
            )
          )
        end
      end

      context 'with merge project' do
        let(:with_merge_project) { merge_project }

        it 'shows merge project' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: 'In this project',
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'new_mr',
                title: 'New merge request',
                href: "/#{merge_project.path_with_namespace}/-/merge_requests/new",
                data: {
                  track_action: 'click_link_new_mr',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top'
                }
              )
            )
          )
        end
      end

      context 'when can create snippet' do
        let(:with_can_create_snippet_in_project) { true }

        it 'shows new snippet' do
          expect(view_model[:menu_sections]).to eq(
            expected_menu_section(
              title: 'In this project',
              menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
                id: 'new_snippet',
                title: 'New snippet',
                href: "/#{project.path_with_namespace}/-/snippets/new",
                data: {
                  track_action: 'click_link_new_snippet_project',
                  track_label: 'plus_menu_dropdown',
                  track_property: 'navigation_top'
                }
              )
            )
          )
        end
      end

      context 'when invite members experiment' do
        let(:with_invite_members_experiment) { true }
        let(:with_can_admin_project_member) { true }
        let(:expected_title) { 'In this project' }
        let(:expected_href) { "/#{project.path_with_namespace}/-/project_members" }

        it_behaves_like 'invite member item', 'projects/invite_members_top_nav_link'
      end
    end

    context 'with persisted group and project' do
      let(:project) { build_stubbed(:project) }
      let(:group) { build_stubbed(:group) }
      let(:current_project) { project }
      let(:current_group) { group }

      before do
        allow(helper).to receive(:show_new_issue_link?).with(project).and_return(true)
        allow(helper).to receive(:can?).with(current_user, :create_projects, group).and_return(true)
      end

      it 'gives precedence to project over group' do
        project_section = expected_menu_section(
          title: 'In this project',
          menu_item: ::Gitlab::Nav::TopNavMenuItem.build(
            id: 'new_issue',
            title: 'New issue',
            href: "/#{project.path_with_namespace}/-/issues/new",
            data: {
              track_action: 'click_link_new_issue',
              track_label: 'plus_menu_dropdown',
              track_property: 'navigation_top',
              qa_selector: 'new_issue_link'
            }
          )
        )
        results = {
          title: title,
          menu_sections: project_section,
          context: project
        }

        expect(view_model).to eq(results)
      end

      context 'without context' do
        let(:with_context) { false }

        it 'does not include context' do
          expect(view_model.keys).to match_array([:title, :menu_sections])
        end
      end
    end

    def expected_menu_section(title:, menu_item:)
      [
        {
          title: title,
          menu_items: [menu_item]
        }
      ]
    end
  end
end
