<script>
import { GlIntersectionObserver, GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions, mapGetters } from 'vuex';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';

import { EPIC_DETAILS_CELL_WIDTH, TIMELINE_CELL_MIN_WIDTH, EPIC_ITEM_HEIGHT } from '../constants';
import eventHub from '../event_hub';
import { generateKey, scrollToCurrentDay } from '../utils/epic_utils';

import CurrentDayIndicator from './current_day_indicator.vue';
import EpicItem from './epic_item.vue';

export default {
  EpicItem,
  epicItemHeight: EPIC_ITEM_HEIGHT,
  components: {
    GlIntersectionObserver,
    GlLoadingIcon,
    EpicItem,
    CurrentDayIndicator,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    presetType: {
      type: String,
      required: true,
    },
    epics: {
      type: Array,
      required: true,
    },
    timeframe: {
      type: Array,
      required: true,
    },
    currentGroupId: {
      type: Number,
      required: true,
    },
    hasFiltersApplied: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      clientWidth: 0,
      emptyRowContainerStyles: {},
      showBottomShadow: false,
      roadmapShellEl: null,
    };
  },
  computed: {
    ...mapState([
      'bufferSize',
      'epicIid',
      'childrenEpics',
      'childrenFlags',
      'epicIds',
      'pageInfo',
      'epicsFetchForNextPageInProgress',
    ]),
    ...mapGetters(['isScopedRoadmap']),
    hasNextPage() {
      return this.pageInfo?.hasNextPage;
    },
    emptyRowContainerVisible() {
      return this.displayedEpics.length < this.bufferSize;
    },
    sectionContainerStyles() {
      return {
        height: `calc(100% - ${60 + this.milestonesHeight}px)`,
        width: `${EPIC_DETAILS_CELL_WIDTH + TIMELINE_CELL_MIN_WIDTH * this.timeframe.length}px`,
      };
    },
    footerMessageHeight() {
      return document.querySelector('.footer-message')?.getBoundingClientRect().height || 0;
    },
    milestonesHeight() {
      return document.querySelector('.milestones-list-section')?.clientHeight || 0;
    },
    epicsWithAssociatedParents() {
      return this.epics.filter((epic) => {
        if (epic.hasParent) {
          if (epic.parent.startDate && epic.parent.dueDate) {
            return this.epicIds.indexOf(epic.parent.id) < 0;
          }
          return epic.ancestors.nodes.every((ancestor) => this.epicIds.indexOf(ancestor.id) < 0);
        }
        return !epic.hasParent;
      });
    },
    displayedEpics() {
      // If roadmap is accessed from epic, return all epics
      if (this.epicIid) {
        return this.epics;
      }

      // Return epics with correct parent associations.
      return this.epicsWithAssociatedParents;
    },
    scrollBarHeight() {
      return this.$parent.$el.getBoundingClientRect().height - this.$parent.$el.clientHeight + 1;
    },
  },
  mounted() {
    eventHub.$on('epicsListScrolled', this.handleEpicsListScroll);
    eventHub.$on('toggleIsEpicExpanded', this.toggleIsEpicExpanded);
    window.addEventListener('resize', this.syncClientWidth);
    this.initMounted();
  },
  beforeDestroy() {
    eventHub.$off('epicsListScrolled', this.handleEpicsListScroll);
    eventHub.$off('toggleIsEpicExpanded', this.toggleIsEpicExpanded);
    window.removeEventListener('resize', this.syncClientWidth);
  },
  methods: {
    ...mapActions(['setBufferSize', 'toggleEpic', 'fetchEpics']),
    initMounted() {
      const containerInnerHeight = this.isScopedRoadmap
        ? this.$root.$el.clientHeight
        : window.innerHeight;
      this.roadmapShellEl = this.$root.$el && this.$root.$el.querySelector('.js-roadmap-shell');
      this.setBufferSize(Math.ceil((containerInnerHeight - this.$el.offsetTop) / EPIC_ITEM_HEIGHT));

      // Wait for component render to complete
      this.$nextTick(() => {
        // We cannot scroll to the indicator immediately
        // on render as it will trigger scroll event leading
        // to timeline expand, so we wait for another render
        // cycle to complete.
        this.$nextTick(() => {
          scrollToCurrentDay(this.$el);
        });

        if (!Object.keys(this.emptyRowContainerStyles).length) {
          this.emptyRowContainerStyles = this.getEmptyRowContainerStyles();
        }
      });

      this.syncClientWidth();
    },
    syncClientWidth() {
      this.clientWidth = this.$root.$el?.clientWidth || 0;
    },
    getEmptyRowContainerStyles() {
      if (this.displayedEpics.length && this.$refs.emptyRowContainer) {
        const { top } = this.$refs.emptyRowContainer.getBoundingClientRect();
        const { offsetTop } = this.$refs.emptyRowContainer;
        return {
          height: this.isScopedRoadmap
            ? `calc(${this.$root.$el.clientHeight}px - ${offsetTop}px)`
            : `calc(100vh - ${top + this.scrollBarHeight + this.footerMessageHeight}px)`,
        };
      }
      return {};
    },
    handleEpicsListScroll({ scrollTop, clientHeight, scrollHeight }) {
      this.showBottomShadow = Math.ceil(scrollTop) + clientHeight < scrollHeight;
    },
    handleScrolledToEnd() {
      if (!this.pageInfo) return;

      const { hasNextPage, endCursor } = this.pageInfo;
      if (!this.epicsFetchForNextPageInProgress && hasNextPage) {
        this.fetchEpics({ endCursor });
      }
    },
    toggleIsEpicExpanded(epic) {
      this.toggleEpic({ parentItem: epic });
    },
    generateKey,
  },
};
</script>

<template>
  <div :style="sectionContainerStyles" class="epics-list-section">
    <epic-item
      v-for="epic in displayedEpics"
      ref="epicItems"
      :key="generateKey(epic)"
      :preset-type="presetType"
      :epic="epic"
      :timeframe="timeframe"
      :current-group-id="currentGroupId"
      :client-width="clientWidth"
      :child-level="0"
      :children-epics="childrenEpics"
      :children-flags="childrenFlags"
      :has-filters-applied="hasFiltersApplied"
    />
    <div v-if="emptyRowContainerVisible" class="epic-item-container">
      <div
        ref="emptyRowContainer"
        :style="emptyRowContainerStyles"
        class="epics-list-item epics-list-item-empty clearfix"
      >
        <span class="epic-details-cell"></span>
        <span
          v-for="(timeframeItem, index) in timeframe"
          :key="index"
          class="epic-timeline-cell gl-display-flex"
        >
          <current-day-indicator :preset-type="presetType" :timeframe-item="timeframeItem" />
        </span>
      </div>
    </div>
    <gl-intersection-observer v-if="hasNextPage" @appear="handleScrolledToEnd">
      <div
        v-if="epicsFetchForNextPageInProgress"
        class="gl-text-center gl-py-3"
        data-testid="next-page-loading"
      >
        <gl-loading-icon inline class="gl-mr-2" />
        {{ s__('GroupRoadmap|Loading epics') }}
      </div>
    </gl-intersection-observer>
    <div
      v-show="showBottomShadow"
      data-testid="epic-scroll-bottom-shadow"
      class="gl-left-auto epic-scroll-bottom-shadow"
    ></div>
  </div>
</template>
