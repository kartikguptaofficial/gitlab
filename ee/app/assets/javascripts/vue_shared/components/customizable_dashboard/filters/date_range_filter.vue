<script>
import {
  GlDaterangePicker,
  GlDropdown,
  GlDropdownItem,
  GlIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { n__ } from '~/locale';
import { dateRangeOptionToFilter, getDateRangeOption } from '../utils';
import { TODAY, DATE_RANGE_OPTIONS, DEFAULT_SELECTED_OPTION_INDEX } from './constants';

export default {
  name: 'DateRangeFilter',
  components: {
    GlDaterangePicker,
    GlDropdown,
    GlDropdownItem,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    defaultOption: {
      type: String,
      required: false,
      default: DATE_RANGE_OPTIONS[DEFAULT_SELECTED_OPTION_INDEX].key,
    },
    startDate: {
      type: Date,
      required: false,
      default: null,
    },
    endDate: {
      type: Date,
      required: false,
      default: null,
    },
    dateRangeLimit: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  data() {
    return {
      selectedOption: getDateRangeOption(this.defaultOption),
    };
  },
  computed: {
    dateRange: {
      get() {
        return { startDate: this.startDate, endDate: this.endDate };
      },
      set({ startDate, endDate }) {
        this.$emit(
          'change',
          dateRangeOptionToFilter({
            ...this.selectedOption,
            startDate,
            endDate,
          }),
        );
      },
    },
    dateRangeTooltip() {
      if (this.dateRangeLimit) {
        return n__(
          'Date range limited to %d day',
          'Date range limited to %d days',
          this.dateRangeLimit,
        );
      }

      return null;
    },
  },
  methods: {
    selectOption(option) {
      this.selectedOption = option;

      const { startDate, endDate, showDateRangePicker = false } = option;

      if (!showDateRangePicker && startDate && endDate) {
        this.dateRange = { startDate, endDate };
      }

      this.showDateRangePicker = showDateRangePicker;
    },
  },
  DATE_RANGE_OPTIONS,
  TODAY,
};
</script>

<template>
  <div
    class="gl-display-flex gl-sm-flex-direction-row gl-gap-3 gl-w-full gl-sm-w-auto"
    :class="{ 'gl-flex-direction-column': selectedOption.showDateRangePicker }"
  >
    <gl-dropdown class="gl-w-full gl-sm-w-auto" :text="selectedOption.text">
      <gl-dropdown-item
        v-for="(option, idx) in $options.DATE_RANGE_OPTIONS"
        :key="idx"
        @click="selectOption(option)"
      >
        {{ option.text }}
      </gl-dropdown-item>
    </gl-dropdown>
    <div class="gl-display-flex gl-gap-3">
      <gl-daterange-picker
        v-if="selectedOption.showDateRangePicker"
        v-model="dateRange"
        :default-start-date="dateRange.startDate"
        :default-end-date="dateRange.endDate"
        :default-max-date="$options.TODAY"
        :max-date-range="dateRangeLimit"
        :to-label="__('To')"
        :from-label="__('From')"
        :tooltip="dateRangeTooltip"
        same-day-selection
      />
      <gl-icon
        v-gl-tooltip
        :title="s__('Analytics|Dates and times are displayed in the UTC timezone')"
        name="information-o"
        class="gl-align-self-end gl-mb-3 gl-text-gray-500 gl-min-w-5"
      />
    </div>
  </div>
</template>
