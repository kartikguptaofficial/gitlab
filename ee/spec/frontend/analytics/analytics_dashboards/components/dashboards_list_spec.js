import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import ProductAnalyticsOnboarding from 'ee/product_analytics/onboarding/components/onboarding_list_item.vue';
import DashboardsList from 'ee/analytics/analytics_dashboards/components/dashboards_list.vue';
import DashboardListItem from 'ee/analytics/analytics_dashboards/components/list/dashboard_list_item.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import {
  I18N_DASHBOARD_LIST_TITLE,
  I18N_DASHBOARD_LIST_DESCRIPTION,
  I18N_DASHBOARD_LIST_LEARN_MORE,
} from 'ee/analytics/analytics_dashboards/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import { createAlert } from '~/alert';
import getAllProductAnalyticsDashboardsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_all_product_analytics_dashboards.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  TEST_COLLECTOR_HOST,
  TEST_TRACKING_KEY,
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE,
} from '../mock_data';

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

Vue.use(VueApollo);

describe('DashboardsList', () => {
  let wrapper;

  const findListItems = () => wrapper.findAllComponents(DashboardListItem);
  const findProductAnalyticsOnboarding = () => wrapper.findComponent(ProductAnalyticsOnboarding);
  const findPageTitle = () => wrapper.findByTestId('title');
  const findPageDescription = () => wrapper.findByTestId('description');
  const findHelpLink = () => wrapper.findByTestId('help-link');
  const findNewDashboardButton = () => wrapper.findByTestId('new-dashboard-button');
  const findVisualizationDesignerButton = () =>
    wrapper.findByTestId('visualization-designer-button');

  const $router = {
    push: jest.fn(),
  };

  let mockAnalyticsDashboardsHandler = jest.fn();

  const createWrapper = (provided = {}) => {
    const mockApollo = createMockApollo([
      [getAllProductAnalyticsDashboardsQuery, mockAnalyticsDashboardsHandler],
    ]);

    wrapper = shallowMountExtended(DashboardsList, {
      apolloProvider: mockApollo,
      stubs: {
        RouterLink: true,
      },
      mocks: {
        $router,
      },
      provide: {
        collectorHost: TEST_COLLECTOR_HOST,
        trackingKey: TEST_TRACKING_KEY,
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
        namespaceFullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        ...provided,
      },
    });
  };

  afterEach(() => {
    mockAnalyticsDashboardsHandler.mockReset();
  });

  describe('by default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render the page title', () => {
      expect(findPageTitle().text()).toBe(I18N_DASHBOARD_LIST_TITLE);
    });

    it('should render the page description', () => {
      expect(findPageDescription().text()).toContain(I18N_DASHBOARD_LIST_DESCRIPTION);
    });

    it('does not render the visualization designer button', () => {
      expect(findVisualizationDesignerButton().exists()).toBe(false);
    });

    it('does not render the new dashboard button', () => {
      expect(findNewDashboardButton().exists()).toBe(false);
    });

    it('should render the help link', () => {
      expect(findHelpLink().text()).toBe(I18N_DASHBOARD_LIST_LEARN_MORE);
      expect(findHelpLink().attributes('href')).toBe(
        helpPagePath('user/analytics/analytics_dashboards'),
      );
    });

    it('does not render any feature or custom dashboards', () => {
      expect(findListItems()).toHaveLength(0);
    });
  });

  describe('when the product analytics feature is enabled', () => {
    const FEATURE = 'productAnalytics';

    beforeEach(() => {
      mockAnalyticsDashboardsHandler = jest
        .fn()
        .mockResolvedValue(TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        features: [FEATURE],
      });
    });

    it('renders the feature component', () => {
      expect(findProductAnalyticsOnboarding().exists()).toBe(true);
    });

    // TODO: Update when backend returns dashboards only for onboarded features
    // https://gitlab.com/gitlab-org/gitlab/-/issues/411608
    it('does not render any dashboards', () => {
      expect(findListItems()).toHaveLength(0);
    });

    describe('and the feature has been set up', () => {
      beforeEach(() => {
        findProductAnalyticsOnboarding().vm.$emit('complete');

        return waitForPromises();
      });

      it('does not render the feature component', () => {
        expect(findProductAnalyticsOnboarding().exists()).toBe(false);
      });

      it('renders a list item for each custom and feature dashboard', () => {
        const expectedDashboards =
          TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data?.project?.productAnalyticsDashboards
            ?.nodes;

        expect(findListItems()).toHaveLength(expectedDashboards.length);

        expectedDashboards.forEach((dashboard, idx) => {
          expect(findListItems().at(idx).props('dashboard')).toEqual(dashboard);
        });
      });
    });

    describe('and the feature component throws an error', () => {
      const message = 'some error';
      const error = new Error(message);

      beforeEach(() => {
        return findProductAnalyticsOnboarding().vm.$emit('error', error, true, message);
      });

      it('creates an alert for the error', () => {
        expect(createAlert).toHaveBeenCalledWith({
          captureError: true,
          message,
          error,
        });
      });

      it('dimisses the alert when the component is destroyed', async () => {
        wrapper.destroy();

        await nextTick();

        expect(mockAlertDismiss).toHaveBeenCalled();
      });
    });
  });

  describe('when the combinedAnalyticsDashboardsEditor feature flag is enabled', () => {
    beforeEach(() => {
      createWrapper({ glFeatures: { combinedAnalyticsDashboardsEditor: true } });
    });

    it('renders the visualization designer button', () => {
      expect(findVisualizationDesignerButton().exists()).toBe(true);
    });

    it('renders the create new dashboard button', () => {
      expect(findNewDashboardButton().exists()).toBe(true);
    });
  });
});
