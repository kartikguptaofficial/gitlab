<script>
import { GlButton, GlButtonGroup, GlLoadingIcon } from '@gitlab/ui';
import PanelsBase from 'ee/vue_shared/components/customizable_dashboard/panels_base.vue';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';

import DataTable from 'ee/analytics/analytics_dashboards/components/visualizations/data_table.vue';
import { convertToTableFormat } from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';

import {
  PANEL_DISPLAY_TYPES,
  PANEL_DISPLAY_TYPE_ITEMS,
  PANEL_VISUALIZATION_HEIGHT,
} from '../../constants';

export default {
  name: 'AnalyticsVisualizationPreview',
  PANEL_DISPLAY_TYPES,
  PANEL_DISPLAY_TYPE_ITEMS,
  components: {
    GlButton,
    GlButtonGroup,
    GlLoadingIcon,
    PanelsBase,
    DataTable,
  },
  props: {
    selectedVisualizationType: {
      type: String,
      required: true,
    },
    displayType: {
      type: String,
      required: true,
    },
    isQueryPresent: {
      type: Boolean,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
    resultSet: {
      type: Object,
      required: false,
      default: null,
    },
    resultVisualization: {
      type: Object,
      required: false,
      default: null,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    dataTableResults() {
      return convertToTableFormat(this.resultSet);
    },
  },
  methods: {
    handleVisualizationError(visualizationTitle, error) {
      createAlert({
        message: sprintf(
          s__('Analytics|An error occurred while loading the %{visualizationTitle} visualization.'),
          { visualizationTitle },
        ),
        error,
        captureError: true,
      });
    },
  },
  PANEL_VISUALIZATION_HEIGHT,
};
</script>

<template>
  <div>
    <div v-if="!isQueryPresent || loading">
      <div class="col-12 gl-mt-4">
        <div class="text-content text-center gl-text-gray-400">
          <h3 v-if="!isQueryPresent" data-testid="measurement-hl" class="gl-text-gray-400">
            {{ s__('Analytics|Start by choosing a metric') }}
          </h3>
          <gl-loading-icon
            v-else-if="loading"
            size="lg"
            class="gl-mt-6"
            data-testid="loading-icon"
          />
        </div>
      </div>
    </div>
    <div v-if="resultSet && isQueryPresent" class="border-light">
      <div class="container gl-mt-3 gl-mb-3">
        <div class="row">
          <div class="col-6">
            <gl-button-group>
              <gl-button
                v-for="buttonDisplayType in $options.PANEL_DISPLAY_TYPE_ITEMS"
                :key="buttonDisplayType.type"
                :selected="displayType === buttonDisplayType.type"
                :icon="buttonDisplayType.icon"
                :data-testid="`select-${buttonDisplayType.type}-button`"
                @click="$emit('selectedDisplayType', buttonDisplayType.type)"
                >{{ buttonDisplayType.title }}</gl-button
              >
            </gl-button-group>
          </div>
        </div>
      </div>
      <div
        v-if="displayType === $options.PANEL_DISPLAY_TYPES.DATA"
        class="grid-stack-item gl-m-5"
        data-testid="grid-stack-panel"
      >
        <div
          class="grid-stack-item-content gl-shadow-sm gl-rounded-base gl-p-4 gl-display-flex gl-flex-direction-column gl-bg-white"
        >
          <strong class="gl-mb-2">{{ s__('Analytics|Resulting Data') }}</strong>
          <!-- Using Datatable specifically for data preview here -->
          <data-table
            :data="dataTableResults"
            data-testid="preview-datatable"
            class="gl-overflow-y-auto"
            :style="{ height: $options.PANEL_VISUALIZATION_HEIGHT }"
            @error="(error) => handleVisualizationError('TITLE', error)"
          />
        </div>
      </div>

      <div
        v-if="displayType === $options.PANEL_DISPLAY_TYPES.VISUALIZATION"
        class="grid-stack-item gl-m-5"
      >
        <panels-base
          v-if="selectedVisualizationType"
          :title="title"
          :visualization="resultVisualization"
          :style="{ height: $options.PANEL_VISUALIZATION_HEIGHT }"
          data-testid="preview-visualization"
          @error="(error) => handleVisualizationError('TITLE', error)"
        />
        <div v-else class="col-12 gl-mt-4">
          <div class="text-content text-center gl-text-gray-400">
            <h3 class="gl-text-gray-400">
              {{ s__('Analytics|Select a visualization type') }}
            </h3>
          </div>
        </div>
      </div>

      <div
        v-if="displayType === $options.PANEL_DISPLAY_TYPES.CODE"
        class="gl-bg-white gl-m-5 gl-p-4 gl-shadow-sm gl-rounded-base"
      >
        <pre
          class="code highlight gl-display-flex gl-bg-transparent gl-border-none"
          data-testid="preview-code"
        ><code>{{ resultVisualization }}</code></pre>
      </div>
    </div>
  </div>
</template>
