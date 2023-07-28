# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Dashboard todos', feature_category: :team_planning do
  let_it_be(:user) { create(:user) }

  let(:page_path) { dashboard_todos_path }

  it_behaves_like 'dashboard ultimate trial callout'

  context 'User has a todo in a epic' do
    let_it_be(:group) { create(:group) }
    let_it_be(:target) { create(:epic, group: group) }
    let_it_be(:note) { create(:note, noteable: target, note: "#{user.to_reference} hello world") }
    let_it_be(:todo) do
      create(
        :todo, :mentioned,
        user: user,
        project: nil,
        group: group,
        target: target,
        author: user,
        note: note
      )
    end

    before do
      stub_licensed_features(epics: true)

      group.add_owner(user)
      sign_in(user)

      visit page_path
    end

    it 'has todo present' do
      expect(page).to have_selector('.todos-list .todo', count: 1)
      expect(page).to have_selector('a', text: user.to_reference)
    end
  end

  context 'when the user has todos in an SSO enforced group' do
    let_it_be(:saml_provider) { create(:saml_provider, enabled: true, enforced_sso: true) }
    let_it_be(:restricted_group) { create(:group, saml_provider: saml_provider) }
    let_it_be(:epic_todo) do
      create(:todo, group: restricted_group, user: user, target: create(:epic, group: restricted_group))
    end

    before do
      stub_licensed_features(group_saml: true)
      create(:group_saml_identity, user: user, saml_provider: saml_provider)

      restricted_group.add_owner(user)

      sign_in(user)
    end

    context 'and the session is not active' do
      it 'shows the user an alert', :aggregate_failures do
        visit page_path

        expect(page).to have_content(s_('GroupSAML|Some to-do items may be hidden because your SAML session has expired. Select the group’s path to reauthenticate and view the hidden to-do items.')) # rubocop:disable Layout/LineLength
        expect(page).to have_link(restricted_group.path, href: /#{sso_group_saml_providers_path(restricted_group)}/)
      end
    end

    context 'and the session is active' do
      before do
        dummy_session = { active_group_sso_sign_ins: { saml_provider.id => DateTime.now } }
        allow(Gitlab::Session).to receive(:current).and_return(dummy_session)
      end

      it 'does not show the user an alert', :aggregate_failures do
        visit page_path

        expect(page).not_to have_content(s_('GroupSAML|Some to-do items may be hidden because your SAML session has expired. Select the group’s path to reauthenticate and view the hidden to-do items.')) # rubocop:disable Layout/LineLength
      end
    end
  end

  context 'when user has review request todo', :saas do
    let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:merge_request) { create(:merge_request, :skip_diff_creation, source_project: project) }
    let_it_be(:merge_request_diff) { create(:merge_request_diff, merge_request: merge_request) }
    let_it_be(:todo) { create(:todo, :review_requested, user: user, project: project, target: merge_request) }

    before_all do
      project.add_developer(user)
    end

    before do
      stub_ee_application_setting(should_check_namespace_plan: true)

      stub_licensed_features(
        summarize_mr_changes: true,
        ai_features: true
      )

      project.reload.root_ancestor.namespace_settings.update!(
        experiment_features_enabled: true,
        third_party_ai_features_enabled: true
      )

      sign_in(user)
    end

    it 'does not show todo with diff summary' do
      visit page_path

      page.within('.js-todos-all') do
        expect(page).not_to have_selector('.todo-llm-summary')
      end
    end

    context 'when merge request has diff summary' do
      let!(:diff_summary) do
        create(
          :merge_request_diff_llm_summary,
          merge_request_diff: merge_request_diff
        )
      end

      it 'shows the todo with diff summary' do
        visit page_path

        page.within('.js-todos-all .todo-llm-summary') do
          expect(page).to have_content(diff_summary.content)
          expect(page).to have_content('Summary generated by AI')
        end
      end
    end
  end

  context 'when user has review submitted todo', :saas do
    let_it_be(:namespace) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, group: namespace) }
    let_it_be(:merge_request) { create(:merge_request, :skip_diff_creation, source_project: project) }
    let_it_be(:merge_request_diff) { create(:merge_request_diff, merge_request: merge_request) }
    let_it_be(:review) { create(:review, merge_request: merge_request) }
    let_it_be(:todo) do
      create(
        :todo,
        :review_submitted,
        author: review.author,
        user: user,
        project: project,
        target: merge_request
      )
    end

    before_all do
      project.add_developer(user)
    end

    before do
      stub_ee_application_setting(should_check_namespace_plan: true)

      stub_licensed_features(
        summarize_submitted_review: true,
        ai_features: true
      )

      project.reload.root_ancestor.namespace_settings.update!(
        experiment_features_enabled: true,
        third_party_ai_features_enabled: true
      )

      sign_in(user)
    end

    it 'does not show todo with review summary' do
      visit page_path

      page.within('.js-todos-all') do
        expect(page).not_to have_selector('.todo-llm-summary')
      end
    end

    context 'when merge request has review summary' do
      let!(:review_summary) do
        create(
          :merge_request_review_llm_summary,
          merge_request_diff: merge_request_diff,
          review: review
        )
      end

      it 'shows the todo with review summary' do
        visit page_path

        page.within('.js-todos-all .todo-llm-summary') do
          expect(page).to have_content(review_summary.content)
          expect(page).to have_content('Summary generated by AI')
        end
      end
    end
  end
end
