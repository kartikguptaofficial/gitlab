<script>
import { GlLoadingIcon, GlInfiniteScroll } from '@gitlab/ui';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl, joinPaths, setUrlParams } from '~/lib/utils/url_utility';
import { isMetaClick, contentTop } from '~/lib/utils/common_utils';
import { sanitize } from '~/lib/dompurify';
import FilteredSearch from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { logError } from '~/lib/logger';
import {
  queryToFilterObj,
  filterObjToQuery,
  filterObjToFilterToken,
  filterTokensToFilterObj,
} from './filters';
import MetricsTable from './metrics_table.vue';

const LIST_VERTICAL_PADDING = 130; // search bar height + some more v padding
const LIST_SEARCH_LIMIT = 50;

export default {
  components: {
    GlLoadingIcon,
    MetricsTable,
    GlInfiniteScroll,
    FilteredSearch,
    UrlSync,
  },
  i18n: {
    searchInputPlaceholder: s__('ObservabilityMetrics|Search metrics starting with...'),
  },
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      loading: false,
      metrics: [],
      filters: queryToFilterObj(window.location.search),
    };
  },
  computed: {
    listHeight() {
      return window.innerHeight - contentTop() - LIST_VERTICAL_PADDING;
    },
    query() {
      return filterObjToQuery(this.filters);
    },
    initialFilterValue() {
      return filterObjToFilterToken(this.filters);
    },
  },
  created() {
    this.fetchMetrics();
  },
  methods: {
    async fetchMetrics() {
      this.loading = true;
      try {
        const { metrics } = await this.observabilityClient.fetchMetrics({
          filters: this.filters,
          limit: LIST_SEARCH_LIMIT,
        });
        this.metrics = metrics;
      } catch (e) {
        createAlert({
          message: s__('ObservabilityMetrics|Failed to load metrics.'),
        });
      } finally {
        this.loading = false;
      }
    },
    onMetricClicked({ metricId, clickEvent = {} }) {
      const external = isMetaClick(clickEvent);
      const metricType = this.metrics.find((m) => m.name === metricId)?.type;
      if (!metricType) {
        logError(
          new Error(`onMetricClicked() - Could not find metric type for metric ${metricId}`),
        );
        return;
      }
      const url = joinPaths(
        window.location.origin,
        window.location.pathname,
        encodeURIComponent(metricId),
      );
      const fullUrl = setUrlParams({ type: encodeURIComponent(metricType) }, url);
      visitUrl(sanitize(fullUrl), external);
    },
    onFilter(filterTokens) {
      this.filters = filterTokensToFilterObj(filterTokens);
      this.metrics = [];

      this.fetchMetrics();
    },
  },
  EMPTY_TOKENS: [],
};
</script>

<template>
  <div>
    <div v-if="loading && metrics.length === 0" class="gl-py-5">
      <gl-loading-icon size="lg" />
    </div>

    <template v-else>
      <url-sync :query="query" />

      <div class="vue-filtered-search-bar-container gl-border-t-none gl-my-6">
        <filtered-search
          :initial-filter-value="initialFilterValue"
          recent-searches-storage-key="recent-metrics-filter-search"
          namespace="metrics-list-filtered-search"
          :tokens="$options.EMPTY_TOKENS"
          :search-input-placeholder="$options.i18n.searchInputPlaceholder"
          @onFilter="onFilter"
        />
      </div>

      <gl-loading-icon v-if="loading && metrics.length > 0" size="lg" />
      <gl-infinite-scroll v-else :fetched-items="metrics.length" :max-list-height="listHeight">
        <template #items>
          <metrics-table :metrics="metrics" @metric-clicked="onMetricClicked" />
        </template>
        <template #default>
          <!-- Override default footer -->
          <span data-testid="metrics-infinite-scrolling-legend"></span>
        </template>
      </gl-infinite-scroll>
    </template>
  </div>
</template>
