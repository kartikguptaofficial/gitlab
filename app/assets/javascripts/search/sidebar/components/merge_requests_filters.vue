<script>
// eslint-disable-next-line no-restricted-imports
import { mapGetters } from 'vuex';
import { statusFilterData } from './status_filter/data';
import StatusFilter from './status_filter/index.vue';
import FiltersTemplate from './filters_template.vue';
import { archivedFilterData } from './archived_filter/data';
import ArchivedFilter from './archived_filter/index.vue';

export default {
  name: 'MergeRequestsFilters',
  components: {
    StatusFilter,
    FiltersTemplate,
    ArchivedFilter,
  },
  computed: {
    ...mapGetters(['currentScope']),
    showArchivedFilter() {
      return archivedFilterData.scopes.includes(this.currentScope);
    },
    showStatusFilter() {
      return Object.values(statusFilterData.scopes).includes(this.currentScope);
    },
  },
};
</script>

<template>
  <filters-template>
    <status-filter v-if="showStatusFilter" class="gl-mb-5" />
    <archived-filter v-if="showArchivedFilter" class="gl-mb-5" />
  </filters-template>
</template>
