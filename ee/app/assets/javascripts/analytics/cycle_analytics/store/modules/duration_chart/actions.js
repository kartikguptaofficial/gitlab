import Api from 'ee/api';
import { deprecatedCreateFlash as createFlash } from '~/flash';
import { __ } from '~/locale';
import * as types from './mutation_types';

export const requestDurationData = ({ commit }) => commit(types.REQUEST_DURATION_DATA);

export const receiveDurationDataError = ({ commit }) => {
  commit(types.RECEIVE_DURATION_DATA_ERROR);
  createFlash(__('There was an error while fetching value stream analytics duration data.'));
};

export const fetchDurationData = ({ dispatch, commit, rootGetters }) => {
  dispatch('requestDurationData');
  const {
    cycleAnalyticsRequestParams,
    activeStages,
    currentGroupPath,
    currentValueStreamId,
  } = rootGetters;
  return Promise.all(
    activeStages.map(stage => {
      const { slug } = stage;

      return Api.cycleAnalyticsDurationChart(
        currentGroupPath,
        currentValueStreamId,
        slug,
        cycleAnalyticsRequestParams,
      ).then(({ data }) => ({
        slug,
        selected: true,
        data,
      }));
    }),
  )
    .then(data => commit(types.RECEIVE_DURATION_DATA_SUCCESS, data))
    .catch(() => dispatch('receiveDurationDataError'));
};

export const updateSelectedDurationChartStages = ({ state, commit }, stages) => {
  const setSelectedPropertyOnStages = data =>
    data.map(stage => {
      const selected = stages.reduce((result, object) => {
        if (object.slug === stage.slug) return true;
        return result;
      }, false);

      return {
        ...stage,
        selected,
      };
    });

  const { durationData } = state;
  const updatedDurationStageData = setSelectedPropertyOnStages(durationData);

  commit(types.UPDATE_SELECTED_DURATION_CHART_STAGES, {
    updatedDurationStageData,
  });
};
