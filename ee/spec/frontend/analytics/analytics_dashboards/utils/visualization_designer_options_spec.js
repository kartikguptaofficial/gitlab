import { getVisualizationOptions } from 'ee/analytics/analytics_dashboards/utils/visualization_designer_options';
import { __ } from '~/locale';

describe('getVisualizationOptions', () => {
  it.each`
    visualizationType | hasTimeDimension | measureSubType               | expectedResult
    ${'DataTable'}    | ${false}         | ${'all'}                     | ${{}}
    ${'SingleStat'}   | ${false}         | ${'all'}                     | ${{}}
    ${'SingleStat'}   | ${false}         | ${'returningUserPercentage'} | ${{ unit: '%' }}
    ${'LineChart'}    | ${false}         | ${'all'}                     | ${{ xAxis: { name: __('Time'), type: 'time' }, yAxis: { name: __('Counts'), type: 'value' } }}
    ${'ColumnChart'}  | ${false}         | ${'all'}                     | ${{ xAxis: { name: __('Dimension'), type: 'category' }, yAxis: { name: __('Counts'), type: 'value' } }}
    ${'ColumnChart'}  | ${true}          | ${'all'}                     | ${{ xAxis: { name: __('Time'), type: 'time' }, yAxis: { name: __('Counts'), type: 'value' } }}
  `(
    `with the visualization type $visualizationType, a measure sub type of $measureSubType, and the time dimension is $hasTimeDimension it should return the correct options`,
    ({ visualizationType, hasTimeDimension, measureSubType, expectedResult }) => {
      const result = getVisualizationOptions(visualizationType, hasTimeDimension, measureSubType);

      expect(result).toStrictEqual(expectedResult);
    },
  );
});
