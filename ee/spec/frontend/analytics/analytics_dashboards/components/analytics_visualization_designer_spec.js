import { nextTick } from 'vue';
import { GlLink, GlSprintf } from '@gitlab/ui';
import { __setMockMetadata } from '@cubejs-client/core';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { stubComponent } from 'helpers/stub_component';
import { mockTracking } from 'helpers/tracking_helper';

import { HTTP_STATUS_CREATED, HTTP_STATUS_FORBIDDEN } from '~/lib/utils/http_status';
import { createAlert } from '~/alert';
import { helpPagePath } from '~/helpers/help_page_helper';
import { confirmAction } from '~/lib/utils/confirm_via_gl_modal/confirm_action';

import { saveProductAnalyticsVisualization } from 'ee/analytics/analytics_dashboards/api/dashboards_api';

import AnalyticsVisualizationDesigner from 'ee/analytics/analytics_dashboards/components/analytics_visualization_designer.vue';
import VisualizationTypeSelector from 'ee/analytics/analytics_dashboards/components/visualization_designer/analytics_visualization_type_selector.vue';
import {
  EVENT_LABEL_USER_VIEWED_VISUALIZATION_DESIGNER,
  EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION,
} from 'ee/analytics/analytics_dashboards/constants';

import { NEW_DASHBOARD_SLUG } from 'ee/vue_shared/components/customizable_dashboard/constants';

import { mockMetaData, TEST_CUSTOM_DASHBOARDS_PROJECT } from '../mock_data';
import { BuilderComponent, QueryBuilder } from '../stubs';

jest.mock('~/lib/utils/confirm_via_gl_modal/confirm_action');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));
jest.mock('ee/analytics/analytics_dashboards/api/dashboards_api');

const showToast = jest.fn();
const routerPush = jest.fn();

describe('AnalyticsVisualizationDesigner', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let trackingSpy;

  const findTitleFormGroup = () => wrapper.findByTestId('visualization-title-form-group');
  const findTitleInput = () => wrapper.findByTestId('visualization-title-input');
  const findMeasureSelector = () => wrapper.findByTestId('panel-measure-selector');
  const findDimensionSelector = () => wrapper.findByTestId('panel-dimension-selector');
  const findSaveButton = () => wrapper.findByTestId('visualization-save-btn');
  const findQueryBuilder = () => wrapper.findByTestId('query-builder');
  const findTypeFormGroup = () => wrapper.findByTestId('visualization-type-form-group');
  const findTypeSelector = () => wrapper.findComponent(VisualizationTypeSelector);
  const findPageTitle = () => wrapper.findByTestId('page-title');
  const findPageDescription = () => wrapper.findByTestId('page-description');
  const findPageDescriptionLink = () => findPageDescription().findComponent(GlLink);

  const setVisualizationTitle = async (newTitle = '') => {
    await findTitleInput().vm.$emit('input', newTitle);
  };

  const setMeasurement = (type = '', subType = '') => {
    findMeasureSelector().vm.$emit('measureSelected', type, subType);
  };

  const setVisualizationType = (type = '') => {
    findTypeSelector().vm.$emit('selectVisualizationType', type);
  };

  const setAllRequiredFields = async () => {
    await setVisualizationTitle('New Title');
    setMeasurement('pageViews', 'all');
    setVisualizationType('SingleStat');
  };

  const mockSaveVisualizationImplementation = async (responseCallback) => {
    saveProductAnalyticsVisualization.mockImplementation(responseCallback);

    await waitForPromises();
  };

  const createWrapper = (sourceDashboardSlug) => {
    const mocks = {
      $toast: {
        show: showToast,
      },
      $route: {
        params: {
          dashboard: sourceDashboardSlug || '',
        },
      },
      $router: {
        push: routerPush,
      },
    };

    wrapper = shallowMountExtended(AnalyticsVisualizationDesigner, {
      stubs: {
        RouterView: true,
        BuilderComponent,
        QueryBuilder,
        GlSprintf,
        VisualizationTypeSelector: stubComponent(VisualizationTypeSelector, {
          template: `<div><button>Dropdown</button></div>`,
        }),
      },
      mocks,
      provide: {
        customDashboardsProject: TEST_CUSTOM_DASHBOARDS_PROJECT,
      },
    });
  };

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, window.document, jest.spyOn);
  });

  describe('when mounted', () => {
    beforeEach(() => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
    });

    it('renders the page title', () => {
      expect(findPageTitle().text()).toBe('Create your visualization');
    });

    it('renders the page description with a link to user documentation', () => {
      expect(findPageDescription().text()).toContain(
        'Use the visualization designer to create custom visualizations. After you save a visualization, you can add it to a dashboard.',
      );

      expect(findPageDescriptionLink().text()).toBe('Learn more');
      expect(findPageDescriptionLink().attributes('href')).toBe(
        helpPagePath('user/analytics/analytics_dashboards', {
          anchor: 'visualization-designer',
        }),
      );
    });

    it('renders title input', () => {
      expect(findTitleInput().exists()).toBe(true);
    });

    it('does not render dimension selector', () => {
      expect(findDimensionSelector().exists()).toBe(false);
    });

    it('render a cancel button that routes to the dashboard listing page', async () => {
      const button = wrapper.findByText('Cancel');

      expect(button.attributes('category')).toBe('secondary');

      await button.vm.$emit('click');

      expect(routerPush).toHaveBeenCalledWith('/');
    });

    it(`tracks the "${EVENT_LABEL_USER_VIEWED_VISUALIZATION_DESIGNER}" event`, () => {
      expect(trackingSpy).toHaveBeenCalledWith(
        expect.any(String),
        EVENT_LABEL_USER_VIEWED_VISUALIZATION_DESIGNER,
        expect.any(Object),
      );
    });

    describe('beforeDestroy', () => {
      it('should dismiss the alert', async () => {
        await setVisualizationTitle('New Title');
        await findSaveButton().vm.$emit('click');

        wrapper.destroy();

        await nextTick();

        expect(mockAlertDismiss).toHaveBeenCalled();
      });
    });
  });

  describe('query builder', () => {
    beforeEach(() => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
    });

    it('shows an alert when a query error occurs', () => {
      const error = new Error();
      findQueryBuilder().vm.$emit('queryStatus', { error });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while loading data',
        captureError: true,
        error,
      });
    });
  });

  describe('when saving', () => {
    beforeEach(() => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
    });

    describe('and there is no title', () => {
      beforeEach(() => {
        findTitleInput().element.focus = jest.fn();

        return findSaveButton().vm.$emit('click');
      });

      it('does not save the dashboard', () => {
        expect(saveProductAnalyticsVisualization).not.toHaveBeenCalled();
      });

      it('shows the invalid state on the title input', () => {
        expect(findTitleFormGroup().attributes('state')).toBe(undefined);
        expect(findTitleFormGroup().attributes('invalid-feedback')).toBe('This field is required.');

        expect(findTitleInput().attributes('state')).toBe(undefined);
      });

      it('sets focus on the dashboard title input', () => {
        expect(findTitleInput().element.focus).toHaveBeenCalled();
      });

      describe('and a user then inputs a title', () => {
        beforeEach(() => setVisualizationTitle('New Title'));

        it('shows title input as valid', () => {
          expect(findTitleFormGroup().attributes('state')).toBe('true');
          expect(findTitleInput().attributes('state')).toBe('true');
        });
      });
    });

    describe('and there is no visualization type selected', () => {
      const findDropdownButton = () => findTypeSelector().find('button').element;

      beforeEach(() => {
        findDropdownButton().focus = jest.fn();

        return findSaveButton().vm.$emit('click');
      });

      it('does not save the dashboard', () => {
        expect(saveProductAnalyticsVisualization).not.toHaveBeenCalled();
      });

      it('shows the invalid state on the type selector', () => {
        expect(findTypeFormGroup().attributes('state')).toBe(undefined);
        expect(findTypeFormGroup().attributes('invalid-feedback')).toBe('This field is required.');
      });

      it('sets focus on the dashboard type dropdown button', () => {
        expect(findDropdownButton().focus).toHaveBeenCalled();
      });

      describe('and a user then selects a type', () => {
        beforeEach(() => setVisualizationType('SingleStat'));

        it('shows type selector as valid', () => {
          expect(findTypeFormGroup().attributes('state')).toBe('true');
        });
      });
    });

    it('creates an alert when the measurement is not selected', async () => {
      await setVisualizationTitle('New Title');
      setVisualizationType('SingleStat');

      await findSaveButton().vm.$emit('click');
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Select a measurement',
        captureError: false,
        error: null,
      });
    });

    describe('when the visualization is valid', () => {
      describe('and it saved successfully', () => {
        beforeEach(async () => {
          await setAllRequiredFields();
          await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

          await findSaveButton().vm.$emit('click');

          return waitForPromises();
        });

        it('creates the visualization file and shows a success toast', () => {
          expect(saveProductAnalyticsVisualization).toHaveBeenCalledWith(
            'new_title',
            {
              data: {
                query: { foo: 'bar' },
                type: 'cube_analytics',
              },
              options: {},
              type: 'SingleStat',
              version: 1,
            },
            TEST_CUSTOM_DASHBOARDS_PROJECT,
          );

          expect(showToast).toHaveBeenCalledWith('Visualization was saved successfully');
        });

        it(`tracks the "${EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION}" event`, () => {
          expect(trackingSpy).toHaveBeenCalledWith(
            expect.any(String),
            EVENT_LABEL_USER_CREATED_CUSTOM_VISUALIZATION,
            expect.any(Object),
          );
        });
      });

      it('dismisses the existing alert after successfully saving', async () => {
        await setVisualizationTitle('New Title');
        await findSaveButton().vm.$emit('click');

        await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

        await setAllRequiredFields();
        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(mockAlertDismiss).toHaveBeenCalled();
      });

      it('and a error happens', async () => {
        await setAllRequiredFields();
        await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_FORBIDDEN }));

        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(createAlert).toHaveBeenCalledWith({
          message: 'Error while saving visualization.',
          error: new Error(
            `Received an unexpected HTTP status while saving visualization: ${HTTP_STATUS_FORBIDDEN}`,
          ),
          captureError: true,
        });
      });

      it('and the server responds with "A file with this name already exists"', async () => {
        await setAllRequiredFields();
        const responseError = new Error();
        responseError.response = {
          data: { message: 'A file with this name already exists' },
        };

        mockSaveVisualizationImplementation(() => {
          throw responseError;
        });

        await findSaveButton().vm.$emit('click');
        await waitForPromises();

        expect(findTitleFormGroup().attributes('state')).toBe(undefined);
        expect(findTitleFormGroup().attributes('invalid-feedback')).toBe(
          'A visualization with that name already exists.',
        );
        expect(findTitleInput().attributes('state')).toBe(undefined);
      });

      it('and an error is thrown', async () => {
        await setAllRequiredFields();
        const newError = new Error();
        mockSaveVisualizationImplementation(() => {
          throw newError;
        });
        await findSaveButton().vm.$emit('click');
        await waitForPromises();
        expect(createAlert).toHaveBeenCalledWith({
          error: newError,
          message: 'Error while saving visualization.',
          captureError: true,
        });
      });
    });
  });

  describe('when cancelling', () => {
    let windowDialogSpy;
    let beforeUnloadEvent;

    beforeEach(() => {
      beforeUnloadEvent = new Event('beforeunload');
      windowDialogSpy = jest.spyOn(beforeUnloadEvent, 'returnValue', 'set');
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper();
      confirmAction.mockReturnValue(new Promise(() => {}));
    });

    afterEach(() => {
      windowDialogSpy.mockRestore();
      confirmAction.mockReset();
    });

    describe('by the "beforeunload" event', () => {
      it('does not show the browser confirm dialog when there are no changes', () => {
        window.dispatchEvent(beforeUnloadEvent);

        expect(windowDialogSpy).not.toHaveBeenCalled();
      });

      it('shows the browser confirm dialog when there are changes', async () => {
        await setVisualizationTitle('New Title');
        window.dispatchEvent(beforeUnloadEvent);

        expect(windowDialogSpy).toHaveBeenCalledWith(
          'Are you sure you want to lose unsaved changes?',
        );
      });
    });

    describe('by the route changing', () => {
      const nextMock = jest.fn();

      it('does not show confirm dialog if there are no changes', () => {
        wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);

        expect(confirmAction).not.toHaveBeenCalled();
      });

      it('shows the confirm dialog if there are changes', async () => {
        await setVisualizationTitle('New Title');
        wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);

        expect(confirmAction).toHaveBeenCalledWith(
          'Are you sure you want to cancel creating this visualization?',
          {
            cancelBtnText: 'Continue creating',
            primaryBtnText: 'Discard changes',
          },
        );
      });

      it('does nothing if the user opts to keep creating', async () => {
        await setVisualizationTitle('New Title');
        confirmAction.mockResolvedValue(false);

        wrapper.vm.$options.beforeRouteLeave.call(wrapper.vm, {}, {}, nextMock);
        await waitForPromises();

        expect(routerPush).not.toHaveBeenCalled();
      });
    });
  });

  describe('when editing for dashboard', () => {
    const setupSaveDashboard = async (dashboard) => {
      __setMockMetadata(jest.fn().mockImplementation(() => mockMetaData));
      createWrapper(dashboard);
      await setAllRequiredFields();

      await mockSaveVisualizationImplementation(() => ({ status: HTTP_STATUS_CREATED }));

      await findSaveButton().vm.$emit('click');
      await waitForPromises();
    };

    it('after save it will redirect for new dashboards', async () => {
      await setupSaveDashboard(NEW_DASHBOARD_SLUG);

      expect(routerPush).toHaveBeenCalledWith('/new');
    });

    it('after save it will redirect for existing dashboards', async () => {
      await setupSaveDashboard('test-source-dashboard');

      expect(routerPush).toHaveBeenCalledWith({
        name: 'dashboard-detail',
        params: {
          slug: 'test-source-dashboard',
          editing: true,
        },
      });
    });
  });
});
