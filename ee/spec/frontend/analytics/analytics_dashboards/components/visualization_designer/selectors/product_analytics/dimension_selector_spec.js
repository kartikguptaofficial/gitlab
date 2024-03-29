import { nextTick } from 'vue';
import { GlLabel, GlDropdownItem } from '@gitlab/ui';
import {
  EVENTS_TABLE_NAME,
  SESSIONS_TABLE_NAME,
  RETURNING_USERS_TABLE_NAME,
} from 'ee/analytics/analytics_dashboards/constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProductAnalyticsDimensionSelector from 'ee/analytics/analytics_dashboards/components/visualization_designer/selectors/product_analytics/dimension_selector.vue';

describe('ProductAnalyticsDimensionSelector', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findDimensionSummary = () => wrapper.findByTestId('dimension-summary');
  const findBackButton = () => wrapper.findByTestId('dimension-back-button');
  const findDimensionLabel = () => wrapper.findComponent(GlLabel);

  const addDimensions = jest.fn();
  const removeDimension = jest.fn();
  const setTimeDimensions = jest.fn();
  const removeTimeDimension = jest.fn();

  const createWrapper = ({ measureType = '', dimensions = [], timeDimensions = [] } = {}) => {
    wrapper = shallowMountExtended(ProductAnalyticsDimensionSelector, {
      propsData: {
        dimensions,
        timeDimensions,
        measureType,
        measureSubType: '',
        addDimensions,
        removeDimension,
        setTimeDimensions,
        removeTimeDimension,
      },
    });
  };

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should not render back button on overview', () => {
      expect(findBackButton().exists()).toBe(false);
    });
  });

  const measuredSubTypes = [
    ['pages-pageUrl-button', 'pageUrl'],
    ['pages-pageUrlpath-button', 'pageUrlpath'],
    ['pages-pageTitle-button', 'pageTitle'],
    ['pages-documentLanguage-button', 'documentLanguage'],
    ['pages-pageUrlhosts-button', 'pageUrlhosts'],
    ['users-pageReferrer-button', 'pageReferrer'],
    ['users-browserLanguage-button', 'browserLanguage'],
    ['users-viewportSize-button', 'viewportSize'],
    ['users-agentName-button', 'agentName'],
  ];

  const measuredSubTypesMultiValues = [
    ['users-agentName-agentVersion-button', ['agentName', 'agentVersion']],
  ];

  describe('calls from overview', () => {
    it.each(measuredSubTypes)('to select %p', async (startbutton, selectMethod) => {
      createWrapper();

      const overViewButton = wrapper.findByTestId(startbutton);

      // Overview
      expect(overViewButton.exists()).toBe(true);
      overViewButton.vm.$emit('click');

      await nextTick();

      expect(addDimensions).toHaveBeenCalledWith(`${EVENTS_TABLE_NAME}.${selectMethod}`);
    });

    it.each(measuredSubTypesMultiValues)(
      'calls from overview for multi value types to select %p',
      async (startbutton, selectMethod) => {
        createWrapper();

        const overViewButton = wrapper.findByTestId(startbutton);

        // Overview
        expect(overViewButton.exists()).toBe(true);
        overViewButton.vm.$emit('click');

        await nextTick();

        // Detail selection checks
        expect(addDimensions).toHaveBeenCalledWith(`${EVENTS_TABLE_NAME}.${selectMethod[0]}`);
        expect(addDimensions).toHaveBeenCalledWith(`${EVENTS_TABLE_NAME}.${selectMethod[1]}`);
      },
    );
  });

  describe('Rendering Sub Page', () => {
    it.each(measuredSubTypes)('for %p', async (startbutton, selectMethod) => {
      createWrapper({
        dimensions: [
          {
            name: selectMethod,
            title: 'Test',
            type: 'string',
            shortTitle: selectMethod,
            suggestFilterValues: true,
            isVisible: true,
          },
        ],
      });

      wrapper.findByTestId(startbutton).vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId(startbutton).exists()).toBe(false);

      expect(findDimensionSummary().exists()).toBe(true);
      expect(findDimensionLabel().props('title')).toContain(selectMethod);

      findDimensionLabel().vm.$emit('close', selectMethod);
      expect(removeDimension).toHaveBeenCalled();
    });

    it.each(measuredSubTypesMultiValues)('for %p', async (startbutton, selectMethod) => {
      createWrapper({
        dimensions: [
          {
            name: selectMethod,
            title: 'Test',
            type: 'string',
            shortTitle: selectMethod[0],
            suggestFilterValues: true,
            isVisible: true,
          },
        ],
      });

      wrapper.findByTestId(startbutton).vm.$emit('click');
      await nextTick();

      expect(wrapper.findByTestId(startbutton).exists()).toBe(false);

      expect(findDimensionSummary().exists()).toBe(true);
      expect(findDimensionLabel().props('title')).toContain(selectMethod[0]);

      findDimensionLabel().vm.$emit('close', selectMethod);
      expect(removeDimension).toHaveBeenCalled();
    });
  });

  describe('when timeDimension is selected', () => {
    it('should setTimeDimensions when a granularity is selected', () => {
      createWrapper({ measureType: 'events' });

      wrapper
        .findByTestId('event-granularities-dd')
        .findComponent(GlDropdownItem)
        .vm.$emit('click');

      expect(setTimeDimensions).toHaveBeenCalledWith([
        {
          dimension: `${EVENTS_TABLE_NAME}.derivedTstamp`,
          granularity: 'seconds',
        },
      ]);
    });

    it('should show correct granularity Label', async () => {
      createWrapper({
        timeDimensions: [
          {
            dimension: `${EVENTS_TABLE_NAME}.utcTime`,
            granularity: 'seconds',
          },
        ],
      });

      wrapper
        .findByTestId('event-granularities-dd')
        .findComponent(GlDropdownItem)
        .vm.$emit('click');

      await nextTick();

      await findDimensionLabel().vm.$emit('close', 'seconds');

      expect(removeTimeDimension).toHaveBeenCalled();
    });
  });

  describe('when sessions measureType', () => {
    beforeEach(() => {
      createWrapper({ measureType: 'sessions' });
    });

    it('should not render any items on overview', () => {
      const overViewButton = wrapper.findByTestId('pages-url-button');

      expect(overViewButton.exists()).toBe(false);
    });

    it('should setTimeDimensions with session field when a granularity is selected', () => {
      wrapper
        .findByTestId('event-granularities-dd')
        .findComponent(GlDropdownItem)
        .vm.$emit('click');

      expect(setTimeDimensions).toHaveBeenCalledWith([
        {
          dimension: `${SESSIONS_TABLE_NAME}.startAt`,
          granularity: 'seconds',
        },
      ]);
    });
  });

  describe('when returningUsers measureType', () => {
    beforeEach(() => {
      createWrapper({ measureType: 'returningUsers' });
    });

    it('should not render any items on overview', () => {
      const overViewButton = wrapper.findByTestId('pages-url-button');

      expect(overViewButton.exists()).toBe(false);
    });

    it('should setTimeDimensions with returningUsers field when a granularity is selected', () => {
      wrapper
        .findByTestId('event-granularities-dd')
        .findComponent(GlDropdownItem)
        .vm.$emit('click');

      expect(setTimeDimensions).toHaveBeenCalledWith([
        {
          dimension: `${RETURNING_USERS_TABLE_NAME}.first_timestamp`,
          granularity: 'seconds',
        },
      ]);
    });
  });

  describe('when add another dimension button is clicked', () => {
    it('should render overview and select page', async () => {
      // Simulate the Dimension change that would happen by Cube Component
      createWrapper({
        dimensions: [
          {
            name: `${EVENTS_TABLE_NAME}.pageUrl`,
            title: 'Test',
            type: 'string',
            shortTitle: `${EVENTS_TABLE_NAME}.pageUrl`,
            suggestFilterValues: true,
            isVisible: true,
          },
        ],
      });
      wrapper.findByTestId('pages-pageUrl-button').vm.$emit('click');
      await nextTick();

      await wrapper.findByTestId('another-dimension-button').vm.$emit('click');

      expect(wrapper.findByTestId('pages-pageUrl-button').exists()).toBe(true);
      expect(findDimensionSummary().exists()).toBe(true);
      expect(wrapper.findByTestId('another-dimension-button').exists()).toBe(false);
    });
  });
});
