import { sprintf } from '~/locale';
import { TEST_HOST } from 'helpers/test_constants';
import {
  TITLE_USAGE_SINCE,
  MINUTES_USED,
  CI_MINUTES_HELP_LINK,
  CI_MINUTES_HELP_LINK_LABEL,
} from 'ee/usage_quotas/pipelines/constants';

export const defaultProvide = {
  namespacePath: 'mygroup',
  namespaceId: '12345',
  userNamespace: false,
  pageSize: '20',
  ciMinutesAnyProjectEnabled: true,
  ciMinutesDisplayMinutesAvailableData: true,
  ciMinutesLastResetDate: '2022-08-01',
  ciMinutesMonthlyMinutesLimit: '100',
  ciMinutesMonthlyMinutesUsed: '20',
  ciMinutesMonthlyMinutesUsedPercentage: '20',
  ciMinutesPurchasedMinutesLimit: '100',
  ciMinutesPurchasedMinutesUsed: '20',
  ciMinutesPurchasedMinutesUsedPercentage: '20',
  namespaceActualPlanName: 'MyGroup',
  buyAdditionalMinutesPath: `${TEST_HOST}/-/subscriptions/buy_minutes?selected_group=12345`,
  buyAdditionalMinutesTarget: '_self',
};

export const pageInfo = {
  __typename: 'PageInfo',
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'eyJpZCI6IjYifQ',
  endCursor: 'eyJpZCI6IjYifQ',
};

export const mockGetCiMinutesUsageNamespace = {
  data: {
    ciMinutesUsage: {
      nodes: [
        {
          month: 'Jan',
          monthIso8601: '2021-01-01',
          minutes: 5,
          sharedRunnersDuration: 60,
        },
        {
          month: 'June',
          monthIso8601: '2022-06-01',
          minutes: 0,
          sharedRunnersDuration: 0,
        },
        {
          month: 'July',
          monthIso8601: '2022-07-01',
          minutes: 5,
          sharedRunnersDuration: 60,
        },
        {
          month: 'August',
          monthIso8601: '2022-08-01',
          minutes: 7,
          sharedRunnersDuration: 80,
        },
      ],
    },
  },
};

export const mockGetCiMinutesUsageNamespaceProjects = {
  data: {
    ciMinutesUsage: {
      nodes: [
        {
          month: 'August',
          monthIso8601: '2022-08-01',
          minutes: 5,
          sharedRunnersDuration: 80,
          projects: {
            nodes: [
              {
                minutes: 5,
                sharedRunnersDuration: 80,
                project: {
                  id: 'gid://gitlab/Project/7',
                  name: 'devcafe-mx',
                  nameWithNamespace: 'Group / devcafe-mx',
                  avatarUrl: null,
                  webUrl: 'http://gdk.test:3000/group/devcafe-mx',
                },
              },
            ],
            pageInfo,
          },
        },
      ],
    },
  },
};

export const emptyMockGetCiMinutesUsageNamespaceProjects = {
  data: {
    ciMinutesUsage: {
      nodes: [
        {
          month: 'July',
          monthIso8601: '2021-07-01',
          minutes: 0,
          sharedRunnersDuration: 0,
          projects: {
            nodes: [],
            pageInfo,
          },
        },
      ],
    },
  },
};

export const defaultProjectListProps = {
  projects: mockGetCiMinutesUsageNamespaceProjects.data.ciMinutesUsage.nodes[0].projects.nodes,
  pageInfo,
};

export const defaultUsageOverviewProps = {
  helpLinkHref: CI_MINUTES_HELP_LINK,
  helpLinkLabel: CI_MINUTES_HELP_LINK_LABEL,
  minutesLimit: defaultProvide.ciMinutesMonthlyMinutesLimit,
  minutesTitle: sprintf(TITLE_USAGE_SINCE, {
    usageSince: defaultProvide.ciMinutesLastResetDate,
  }),
  minutesUsed: sprintf(MINUTES_USED, {
    minutesUsed: `${defaultProvide.ciMinutesMonthlyMinutesUsed} / ${defaultProvide.ciMinutesMonthlyMinutesLimit}`,
  }),
  minutesUsedPercentage: defaultProvide.ciMinutesMonthlyMinutesUsedPercentage,
};
