import { transformFilters, generateChartDateRangeData } from 'ee/issues_analytics/utils';
import { mockOriginalFilters, mockFilters, mockChartDateRangeData } from './mock_data';

describe('Issues Analytics utils', () => {
  describe('transformFilters', () => {
    it('transforms the object keys as expected', () => {
      const filters = transformFilters(mockOriginalFilters);

      expect(filters).toEqual(mockFilters);
    });

    it('groups negated filters into a single `not` object', () => {
      const originalNegatedFilters = {
        'not[author_username]': 'john_smith',
        'not[label_name]': ['Phant'],
        'not[epic_id]': '4',
      };

      const negatedFilters = {
        not: {
          authorUsername: 'john_smith',
          labelName: ['Phant'],
          epicId: '4',
        },
      };

      const filters = transformFilters({ ...mockOriginalFilters, ...originalNegatedFilters });

      expect(filters).toEqual({ ...mockFilters, ...negatedFilters });
    });

    it('renames keys when new key names are provided', () => {
      const newKeys = { labelName: 'labelNames', assigneeUsername: 'assigneeUsernames' };
      const originalFilters = { label_name: [], assignee_username: [], author_username: 'bob' };
      const newFilters = { labelNames: [], assigneeUsernames: [], authorUsername: 'bob' };
      const filters = transformFilters(originalFilters, newKeys);

      expect(filters).toEqual(newFilters);
    });
  });

  describe('generateChartDateRangeData', () => {
    const startDate = new Date('2023-07-04T00:00:00.000Z');
    const endDate = new Date('2023-09-15T00:00:00.000Z');

    it('returns the data as expected', () => {
      const chartDateRangeData = generateChartDateRangeData(startDate, endDate);

      expect(chartDateRangeData).toEqual(mockChartDateRangeData);
    });

    it('returns an empty array when given an invalid date range', () => {
      const chartDateRangeData = generateChartDateRangeData(endDate, startDate);

      expect(chartDateRangeData).toEqual([]);
    });
  });
});
