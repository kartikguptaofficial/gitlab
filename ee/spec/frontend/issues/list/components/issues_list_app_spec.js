import { mount } from '@vue/test-utils';
import { cloneDeep } from 'lodash';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import getIssuesQuery from 'ee_else_ce/issues/list/queries/get_issues.query.graphql';
import getIssuesCountsQuery from 'ee_else_ce/issues/list/queries/get_issues_counts.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getIssuesCountsQueryResponse, getIssuesQueryResponse } from 'jest/issues/list/mock_data';
import { TYPENAME_USER } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import IssuableList from '~/vue_shared/issuable/list/components/issuable_list_root.vue';
import {
  CREATED_DESC,
  TYPE_TOKEN_OBJECTIVE_OPTION,
  TYPE_TOKEN_KEY_RESULT_OPTION,
  TYPE_TOKEN_EPIC_OPTION,
} from '~/issues/list/constants';
import CEIssuesListApp from '~/issues/list/components/issues_list_app.vue';
import {
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  WORK_ITEM_TYPE_ENUM_EPIC,
} from '~/work_items/constants';
import {
  TOKEN_TYPE_ASSIGNEE,
  TOKEN_TYPE_AUTHOR,
  TOKEN_TYPE_CONFIDENTIAL,
  TOKEN_TYPE_CONTACT,
  TOKEN_TYPE_EPIC,
  TOKEN_TYPE_HEALTH,
  TOKEN_TYPE_ITERATION,
  TOKEN_TYPE_LABEL,
  TOKEN_TYPE_MILESTONE,
  TOKEN_TYPE_MY_REACTION,
  TOKEN_TYPE_ORGANIZATION,
  TOKEN_TYPE_RELEASE,
  TOKEN_TYPE_TYPE,
  TOKEN_TYPE_SEARCH_WITHIN,
  TOKEN_TYPE_WEIGHT,
  TOKEN_TYPE_CREATED,
  TOKEN_TYPE_CLOSED,
} from 'ee/vue_shared/components/filtered_search_bar/constants';
import BlockingIssuesCount from 'ee/issues/components/blocking_issues_count.vue';
import IssuesListApp from 'ee/issues/list/components/issues_list_app.vue';
import NewIssueDropdown from 'ee/issues/list/components/new_issue_dropdown.vue';
import CreateWorkItemForm from 'ee/work_items/components/create_work_item_form.vue';

describe('EE IssuesListApp component', () => {
  let wrapper;

  Vue.use(VueApollo);

  const defaultProvide = {
    autocompleteAwardEmojisPath: 'autocomplete/award/emojis/path',
    calendarPath: 'calendar/path',
    canBulkUpdate: false,
    canCreateProjects: false,
    canReadCrmContact: false,
    canReadCrmOrganization: false,
    emptyStateSvgPath: 'empty-state.svg',
    exportCsvPath: 'export/csv/path',
    fullPath: 'path/to/project',
    groupPath: 'group/path',
    hasAnyIssues: true,
    hasAnyProjects: true,
    hasBlockedIssuesFeature: true,
    hasEpicsFeature: true,
    hasIssueDateFilterFeature: true,
    hasIssuableHealthStatusFeature: true,
    hasIssueWeightsFeature: true,
    hasIterationsFeature: true,
    hasScopedLabelsFeature: true,
    hasOkrsFeature: true,
    initialEmail: 'email@example.com',
    initialSort: CREATED_DESC,
    isIssueRepositioningDisabled: false,
    isProject: true,
    isPublicVisibilityRestricted: false,
    isSignedIn: true,
    jiraIntegrationPath: 'jira/integration/path',
    newIssuePath: 'new/issue/path',
    newProjectPath: 'new/project/path',
    releasesPath: 'releases/path',
    rssPath: 'rss/path',
    showNewIssueLink: true,
    signInPath: 'sign/in/path',
    groupId: '',
  };

  const defaultQueryResponse = cloneDeep(getIssuesQueryResponse);
  defaultQueryResponse.data.project.issues.nodes[0].blockingCount = 1;
  defaultQueryResponse.data.project.issues.nodes[0].healthStatus = null;
  defaultQueryResponse.data.project.issues.nodes[0].weight = 5;

  const findIssuableList = () => wrapper.findComponent(IssuableList);
  const findIssueListApp = () => wrapper.findComponent(CEIssuesListApp);
  const findCreateWorkItemForm = () => wrapper.findComponent(CreateWorkItemForm);
  const findNewIssueDropdown = () => wrapper.findComponent(NewIssueDropdown);

  const mountComponent = ({
    provide = {},
    okrsMvc = false,
    issuesQueryResponse = jest.fn().mockResolvedValue(defaultQueryResponse),
    issuesCountsQueryResponse = jest.fn().mockResolvedValue(getIssuesCountsQueryResponse),
  } = {}) => {
    return mount(IssuesListApp, {
      apolloProvider: createMockApollo([
        [getIssuesQuery, issuesQueryResponse],
        [getIssuesCountsQuery, issuesCountsQueryResponse],
      ]),
      provide: {
        glFeatures: {
          okrsMvc,
        },
        ...defaultProvide,
        ...provide,
      },
    });
  };

  describe('template', () => {
    beforeEach(async () => {
      wrapper = mountComponent();
      jest.runOnlyPendingTimers();
      await waitForPromises();
    });

    it('shows blocking issues count', () => {
      expect(wrapper.findComponent(BlockingIssuesCount).props('blockingIssuesCount')).toBe(
        defaultQueryResponse.data.project.issues.nodes[0].blockingCount,
      );
    });
  });

  describe('workItemTypes', () => {
    describe.each`
      hasEpicsFeature | isProject | eeWorkItemTypes               | message
      ${false}        | ${true}   | ${[]}                         | ${'NOT include'}
      ${true}         | ${true}   | ${[]}                         | ${'NOT include'}
      ${true}         | ${false}  | ${[WORK_ITEM_TYPE_ENUM_EPIC]} | ${'include'}
    `(
      'when hasEpicsFeature is "$hasEpicsFeature" and isProject is "$isProject"',
      ({ hasEpicsFeature, isProject, eeWorkItemTypes, message }) => {
        beforeEach(() => {
          wrapper = mountComponent({ provide: { hasEpicsFeature, isProject } });
        });

        it(`should ${message} epic in work item types`, () => {
          expect(findIssueListApp().props('eeWorkItemTypes')).toMatchObject(eeWorkItemTypes);
        });
      },
    );

    describe.each`
      hasOkrsFeature | okrsMvc  | eeWorkItemTypes                                                    | message
      ${false}       | ${true}  | ${[]}                                                              | ${'NOT include'}
      ${true}        | ${false} | ${[]}                                                              | ${'NOT include'}
      ${true}        | ${true}  | ${[WORK_ITEM_TYPE_ENUM_OBJECTIVE, WORK_ITEM_TYPE_ENUM_KEY_RESULT]} | ${'include'}
    `(
      'when hasOkrsFeature is "$hasOkrsFeature" and okrsMvc is "$okrsMvc"',
      ({ hasOkrsFeature, okrsMvc, eeWorkItemTypes, message }) => {
        beforeEach(() => {
          wrapper = mountComponent({
            provide: {
              hasOkrsFeature,
            },
            okrsMvc,
          });
        });

        it(`should ${message} objective and key result in work item types`, () => {
          expect(findIssueListApp().props('eeWorkItemTypes')).toMatchObject(eeWorkItemTypes);
        });
      },
    );
  });

  describe('typeTokenOptions', () => {
    describe.each`
      hasEpicsFeature | isProject | eeWorkItemTypeTokens        | message
      ${false}        | ${true}   | ${[]}                       | ${'NOT include'}
      ${true}         | ${true}   | ${[]}                       | ${'NOT include'}
      ${true}         | ${false}  | ${[TYPE_TOKEN_EPIC_OPTION]} | ${'include'}
    `(
      'when hasEpicsFeature is "$hasEpicsFeature" and isProject is "$isProject"',
      ({ hasEpicsFeature, isProject, eeWorkItemTypeTokens, message }) => {
        beforeEach(() => {
          wrapper = mountComponent({ provide: { hasEpicsFeature, isProject } });
        });

        it(`should ${message} epic in type tokens`, () => {
          expect(findIssueListApp().props('eeTypeTokenOptions')).toMatchObject(
            eeWorkItemTypeTokens,
          );
        });
      },
    );

    describe.each`
      hasOkrsFeature | okrsMvc  | eeWorkItemTypeTokens                                           | message
      ${false}       | ${true}  | ${[]}                                                          | ${'NOT include'}
      ${true}        | ${false} | ${[]}                                                          | ${'NOT include'}
      ${true}        | ${true}  | ${[TYPE_TOKEN_OBJECTIVE_OPTION, TYPE_TOKEN_KEY_RESULT_OPTION]} | ${'include'}
    `(
      'when hasOkrsFeature is "$hasOkrsFeature" and okrsMvc is "$okrsMvc"',
      ({ hasOkrsFeature, okrsMvc, eeWorkItemTypeTokens, message }) => {
        beforeEach(() => {
          wrapper = mountComponent({
            provide: {
              hasOkrsFeature,
            },
            okrsMvc,
          });
        });

        it(`should ${message} objective and key result in type tokens`, () => {
          expect(findIssueListApp().props('eeTypeTokenOptions')).toMatchObject(
            eeWorkItemTypeTokens,
          );
        });
      },
    );
  });

  describe('tokens', () => {
    const mockCurrentUser = {
      id: 1,
      name: 'Administrator',
      username: 'root',
      avatar_url: 'avatar/url',
    };

    describe.each`
      feature         | property                    | tokenName      | type
      ${'iterations'} | ${'hasIterationsFeature'}   | ${'Iteration'} | ${TOKEN_TYPE_ITERATION}
      ${'epics'}      | ${'groupPath'}              | ${'Epic'}      | ${TOKEN_TYPE_EPIC}
      ${'weights'}    | ${'hasIssueWeightsFeature'} | ${'Weight'}    | ${TOKEN_TYPE_WEIGHT}
    `('when $feature are not available', ({ property, tokenName, type }) => {
      beforeEach(() => {
        wrapper = mountComponent({ provide: { [property]: '' } });
      });

      it(`does not render ${tokenName} token`, () => {
        expect(findIssuableList().props('searchTokens')).not.toMatchObject([{ type }]);
      });
    });

    describe('when all tokens are available', () => {
      beforeEach(() => {
        window.gon = {
          current_user_id: mockCurrentUser.id,
          current_user_fullname: mockCurrentUser.name,
          current_username: mockCurrentUser.username,
          current_user_avatar_url: mockCurrentUser.avatar_url,
        };

        wrapper = mountComponent({
          provide: {
            canReadCrmContact: true,
            canReadCrmOrganization: true,
            groupPath: 'group/path',
            hasIssueWeightsFeature: true,
            hasIterationsFeature: true,
            isSignedIn: true,
          },
        });
      });

      it('renders all tokens alphabetically', () => {
        const preloadedUsers = [
          { ...mockCurrentUser, id: convertToGraphQLId(TYPENAME_USER, mockCurrentUser.id) },
        ];

        expect(findIssuableList().props('searchTokens')).toMatchObject([
          { type: TOKEN_TYPE_ASSIGNEE, preloadedUsers },
          { type: TOKEN_TYPE_AUTHOR, preloadedUsers },
          { type: TOKEN_TYPE_CLOSED },
          { type: TOKEN_TYPE_CONFIDENTIAL },
          { type: TOKEN_TYPE_CONTACT },
          { type: TOKEN_TYPE_CREATED },
          { type: TOKEN_TYPE_EPIC },
          { type: TOKEN_TYPE_HEALTH },
          { type: TOKEN_TYPE_ITERATION },
          { type: TOKEN_TYPE_LABEL },
          { type: TOKEN_TYPE_MILESTONE },
          { type: TOKEN_TYPE_MY_REACTION },
          { type: TOKEN_TYPE_ORGANIZATION },
          { type: TOKEN_TYPE_RELEASE },
          { type: TOKEN_TYPE_SEARCH_WITHIN },
          { type: TOKEN_TYPE_TYPE },
          { type: TOKEN_TYPE_WEIGHT },
        ]);
      });
    });
  });

  describe('NewIssueDropdown component', () => {
    describe('when okrs is enabled', () => {
      beforeEach(() => {
        wrapper = mountComponent({
          provide: { hasOkrsFeature: true },
          okrsMvc: true,
        });
      });

      it('renders', () => {
        expect(findNewIssueDropdown().props()).toEqual({ workItemType: 'Objective' });
      });
    });

    describe('when okrs is disabled', () => {
      beforeEach(() => {
        wrapper = mountComponent({
          provide: { hasOkrsFeature: false },
          okrsMvc: false,
        });
      });

      it('does not render', () => {
        expect(findNewIssueDropdown().exists()).toBe(false);
      });
    });
  });

  describe('CreateWorkItemForm component', () => {
    describe('when okrs is enabled', () => {
      beforeEach(() => {
        wrapper = mountComponent({
          provide: { hasOkrsFeature: true },
          okrsMvc: true,
        });
      });

      it('does not render initially', () => {
        expect(findCreateWorkItemForm().exists()).toBe(false);
      });

      describe('when "New Objective" button is clicked', () => {
        beforeEach(() => {
          findNewIssueDropdown().vm.$emit('select-new-work-item');
        });

        it('renders', () => {
          expect(findCreateWorkItemForm().props()).toEqual({
            isGroup: false,
            workItemType: 'Objective',
          });
        });

        it('hides form when "hide" event is emitted', async () => {
          findCreateWorkItemForm().vm.$emit('hide');
          await nextTick();

          expect(findCreateWorkItemForm().exists()).toBe(false);
        });
      });
    });

    describe('when okrs is disabled', () => {
      beforeEach(() => {
        wrapper = mountComponent({
          provide: { hasOkrsFeature: false },
          okrsMvc: false,
        });
      });

      it('does not render', () => {
        expect(findCreateWorkItemForm().exists()).toBe(false);
      });
    });
  });
});
