import { shallowMount } from '@vue/test-utils';
import PanelType from '~/monitoring/components/panel_type.vue';
import EmptyChart from '~/monitoring/components/charts/empty_chart.vue';
import TimeSeriesChart from '~/monitoring/components/charts/time_series.vue';
import AnomalyChart from '~/monitoring/components/charts/anomaly.vue';
import { graphDataPrometheusQueryRange } from './mock_data';
import { anomalyMockGraphData } from '../../frontend/monitoring/mock_data';
import { createStore } from '~/monitoring/stores';

describe('Panel Type component', () => {
  let store;
  let panelType;
  const dashboardWidth = 100;

  describe('When no graphData is available', () => {
    let glEmptyChart;
    // Deep clone object before modifying
    const graphDataNoResult = JSON.parse(JSON.stringify(graphDataPrometheusQueryRange));
    graphDataNoResult.queries[0].result = [];

    beforeEach(() => {
      panelType = shallowMount(PanelType, {
        propsData: {
          clipboardText: 'dashboard_link',
          dashboardWidth,
          graphData: graphDataNoResult,
        },
      });
    });

    afterEach(() => {
      panelType.destroy();
    });

    describe('Empty Chart component', () => {
      beforeEach(() => {
        glEmptyChart = panelType.find(EmptyChart);
      });

      it('is a Vue instance', () => {
        expect(glEmptyChart.isVueInstance()).toBe(true);
      });

      it('it receives a graph title', () => {
        const props = glEmptyChart.props();

        expect(props.graphTitle).toBe(panelType.vm.graphData.title);
      });
    });
  });

  describe('when Graph data is available', () => {
    const exampleText = 'example_text';
    const propsData = {
      clipboardText: exampleText,
      dashboardWidth,
      graphData: graphDataPrometheusQueryRange,
    };

    beforeEach(done => {
      store = createStore();
      panelType = shallowMount(PanelType, {
        propsData,
        sync: false,
        store,
      });
      panelType.vm.$nextTick(done);
    });

    describe('Time Series Chart panel type', () => {
      it('is rendered', () => {
        expect(panelType.find(TimeSeriesChart).isVueInstance()).toBe(true);
        expect(panelType.find(TimeSeriesChart).exists()).toBe(true);
      });

      it('sets clipboard text on the dropdown', () => {
        const link = () => panelType.find('.js-chart-link');
        const clipboardText = () => link().element.dataset.clipboardText;

        expect(clipboardText()).toBe(exampleText);
      });
    });

    describe('Anomaly Chart panel type', () => {
      beforeEach(done => {
        panelType.setProps({
          graphData: anomalyMockGraphData,
        });
        panelType.vm.$nextTick(done);
      });

      it('is rendered with an anomaly chart', () => {
        expect(panelType.find(AnomalyChart).isVueInstance()).toBe(true);
        expect(panelType.find(AnomalyChart).exists()).toBe(true);
      });
    });
  });
});
