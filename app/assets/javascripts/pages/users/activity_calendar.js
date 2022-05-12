import { select } from 'd3-selection';
import dateFormat from 'dateformat';
import $ from 'jquery';
import { last } from 'lodash';
import createFlash from '~/flash';
import axios from '~/lib/utils/axios_utils';
import { getDayName, getDayDifference } from '~/lib/utils/datetime_utility';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { n__, s__, __ } from '~/locale';
import { loadingIconForLegacyJS } from '~/loading_icon_for_legacy_js';

const d3 = { select };

const firstDayOfWeekChoices = Object.freeze({
  sunday: 0,
  monday: 1,
  saturday: 6,
});

const CONTRIB_LEGENDS = [
  { title: __('No contributions'), min: 0 },
  { title: __('1-9 contributions'), min: 1 },
  { title: __('10-19 contributions'), min: 10 },
  { title: __('20-29 contributions'), min: 20 },
  { title: __('30+ contributions'), min: 30 },
];

function getSystemDate(systemUtcOffsetSeconds) {
  const date = new Date();
  const localUtcOffsetMinutes = 0 - date.getTimezoneOffset();
  const systemUtcOffsetMinutes = systemUtcOffsetSeconds / 60;
  date.setMinutes(date.getMinutes() - localUtcOffsetMinutes + systemUtcOffsetMinutes);
  return date;
}

function formatTooltipText({ date, count }) {
  const dateObject = new Date(date);
  const dateDayName = getDayName(dateObject);
  const dateText = dateFormat(dateObject, 'mmm d, yyyy');

  let contribText = __('No contributions');
  if (count > 0) {
    contribText = n__('%d contribution', '%d contributions', count);
  }
  return `${contribText}<br /><span class="gl-text-gray-300">${dateDayName} ${dateText}</span>`;
}

// Return the contribution level from the number of contributions
export const getLevelFromContributions = (count) => {
  if (count <= 0) {
    return 0;
  }

  const nextLevel = CONTRIB_LEGENDS.findIndex(({ min }) => count < min);

  // If there is no higher level, we are at the end
  return nextLevel >= 0 ? nextLevel - 1 : CONTRIB_LEGENDS.length - 1;
};

export default class ActivityCalendar {
  constructor(
    container,
    activitiesContainer,
    timestamps,
    calendarActivitiesPath,
    utcOffset = 0,
    firstDayOfWeek = firstDayOfWeekChoices.sunday,
    monthsAgo = 12,
  ) {
    this.calendarActivitiesPath = calendarActivitiesPath;
    this.clickDay = this.clickDay.bind(this);
    this.currentSelectedDate = '';
    this.daySpace = 1;
    this.daySize = 15;
    this.daySizeWithSpace = this.daySize + this.daySpace * 2;
    this.monthNames = [
      __('Jan'),
      __('Feb'),
      __('Mar'),
      __('Apr'),
      __('May'),
      __('Jun'),
      __('Jul'),
      __('Aug'),
      __('Sep'),
      __('Oct'),
      __('Nov'),
      __('Dec'),
    ];
    this.months = [];
    this.firstDayOfWeek = firstDayOfWeek;
    this.activitiesContainer = activitiesContainer;
    this.container = container;

    // Loop through the timestamps to create a group of objects
    // The group of objects will be grouped based on the day of the week they are
    this.timestampsTmp = [];
    let group = 0;

    const today = getSystemDate(utcOffset);
    today.setHours(0, 0, 0, 0, 0);

    const timeAgo = new Date(today);
    timeAgo.setMonth(today.getMonth() - monthsAgo);

    const days = getDayDifference(timeAgo, today);

    for (let i = 0; i <= days; i += 1) {
      const date = new Date(timeAgo);
      date.setDate(date.getDate() + i);

      const day = date.getDay();
      const count = timestamps[dateFormat(date, 'yyyy-mm-dd')] || 0;

      // Create a new group array if this is the first day of the week
      // or if is first object
      if ((day === this.firstDayOfWeek && i !== 0) || i === 0) {
        this.timestampsTmp.push([]);
        group += 1;
      }

      // Push to the inner array the values that will be used to render map
      const innerArray = this.timestampsTmp[group - 1];
      innerArray.push({ count, date, day });
    }

    // Init the svg element
    this.svg = this.renderSvg(container, group);
    this.renderDays();
    this.renderMonths();
    this.renderDayTitles();
    this.renderKey();
  }

  // Add extra padding for the last month label if it is also the last column
  getExtraWidthPadding(group) {
    let extraWidthPadding = 0;
    const lastColMonth = this.timestampsTmp[group - 1][0].date.getMonth();
    const secondLastColMonth = this.timestampsTmp[group - 2][0].date.getMonth();

    if (lastColMonth !== secondLastColMonth) {
      extraWidthPadding = 6;
    }

    return extraWidthPadding;
  }

  renderSvg(container, group) {
    const width = (group + 1) * this.daySizeWithSpace + this.getExtraWidthPadding(group);
    return d3
      .select(container)
      .append('svg')
      .attr('width', width)
      .attr('height', 167)
      .attr('class', 'contrib-calendar');
  }

  dayYPos(day) {
    return this.daySizeWithSpace * ((day + 7 - this.firstDayOfWeek) % 7);
  }

  renderDays() {
    this.svg
      .selectAll('g')
      .data(this.timestampsTmp)
      .enter()
      .append('g')
      .attr('transform', (group, i) => {
        group.forEach((stamp, a) => {
          if (a === 0 && stamp.day === this.firstDayOfWeek) {
            const month = stamp.date.getMonth();
            const x = this.daySizeWithSpace * i + 1 + this.daySizeWithSpace;
            const lastMonth = last(this.months);
            if (
              lastMonth == null ||
              (month !== lastMonth.month && x - this.daySizeWithSpace !== lastMonth.x)
            ) {
              this.months.push({ month, x });
            }
          }
        });
        return `translate(${this.daySizeWithSpace * i + 1 + this.daySizeWithSpace}, 18)`;
      })
      .selectAll('rect')
      .data((stamp) => stamp)
      .enter()
      .append('rect')
      .attr('x', '0')
      .attr('y', (stamp) => this.dayYPos(stamp.day))
      .attr('width', this.daySize)
      .attr('height', this.daySize)
      .attr('data-level', (stamp) => getLevelFromContributions(stamp.count))
      .attr('title', (stamp) => formatTooltipText(stamp))
      .attr('class', 'user-contrib-cell has-tooltip')
      .attr('data-html', true)
      .attr('data-container', 'body')
      .on('click', this.clickDay);
  }

  renderDayTitles() {
    const days = [
      {
        text: s__('DayTitle|M'),
        y: 29 + this.dayYPos(1),
      },
      {
        text: s__('DayTitle|W'),
        y: 29 + this.dayYPos(3),
      },
      {
        text: s__('DayTitle|F'),
        y: 29 + this.dayYPos(5),
      },
    ];

    if (this.firstDayOfWeek === firstDayOfWeekChoices.monday) {
      days.push({
        text: s__('DayTitle|S'),
        y: 29 + this.dayYPos(7),
      });
    } else if (this.firstDayOfWeek === firstDayOfWeekChoices.saturday) {
      days.push({
        text: s__('DayTitle|S'),
        y: 29 + this.dayYPos(6),
      });
    }

    this.svg
      .append('g')
      .selectAll('text')
      .data(days)
      .enter()
      .append('text')
      .attr('text-anchor', 'middle')
      .attr('x', 8)
      .attr('y', (day) => day.y)
      .text((day) => day.text)
      .attr('class', 'user-contrib-text');
  }

  renderMonths() {
    this.svg
      .append('g')
      .attr('direction', 'ltr')
      .selectAll('text')
      .data(this.months)
      .enter()
      .append('text')
      .attr('x', (date) => date.x)
      .attr('y', 10)
      .attr('class', 'user-contrib-text')
      .text((date) => this.monthNames[date.month]);
  }

  renderKey() {
    this.svg
      .append('g')
      .attr('transform', `translate(18, ${this.daySizeWithSpace * 8 + 16})`)
      .selectAll('rect')
      .data(CONTRIB_LEGENDS)
      .enter()
      .append('rect')
      .attr('width', this.daySize)
      .attr('height', this.daySize)
      .attr('x', (_, i) => this.daySizeWithSpace * i)
      .attr('y', 0)
      .attr('data-level', (_, i) => i)
      .attr('class', 'user-contrib-cell has-tooltip contrib-legend')
      .attr('title', (x) => x.title)
      .attr('data-container', 'body')
      .attr('data-html', true);
  }

  clickDay(stamp) {
    if (this.currentSelectedDate !== stamp.date) {
      this.currentSelectedDate = stamp.date;

      const date = [
        this.currentSelectedDate.getFullYear(),
        this.currentSelectedDate.getMonth() + 1,
        this.currentSelectedDate.getDate(),
      ].join('-');

      $(this.activitiesContainer)
        .empty()
        .append(loadingIconForLegacyJS({ size: 'lg' }));

      axios
        .get(this.calendarActivitiesPath, {
          params: {
            date,
          },
          responseType: 'text',
        })
        .then(({ data }) => {
          $(this.activitiesContainer).html(data);
          document
            .querySelector(this.activitiesContainer)
            .querySelectorAll('.js-localtime')
            .forEach((el) => {
              el.setAttribute('title', formatDate(el.getAttribute('data-datetime')));
            });
        })
        .catch(() =>
          createFlash({
            message: __('An error occurred while retrieving calendar activity'),
          }),
        );
    } else {
      this.currentSelectedDate = '';
      $(this.activitiesContainer).html('');
    }
  }
}
