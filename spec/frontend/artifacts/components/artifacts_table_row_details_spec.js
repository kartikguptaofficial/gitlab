import { RecycleScroller, DynamicScroller } from 'vendor/vue-virtual-scroller';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import getJobArtifactsResponse from 'test_fixtures/graphql/artifacts/graphql/queries/get_job_artifacts.query.graphql.json';
import waitForPromises from 'helpers/wait_for_promises';
import ArtifactsTableRowDetails from '~/artifacts/components/artifacts_table_row_details.vue';
import ArtifactRow from '~/artifacts/components/artifact_row.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import destroyArtifactMutation from '~/artifacts/graphql/mutations/destroy_artifact.mutation.graphql';
import { i18n } from '~/artifacts/constants';
import { createAlert } from '~/flash';

jest.mock('~/flash');

const { artifacts } = getJobArtifactsResponse.data.project.jobs.nodes[0];
const refetchArtifacts = jest.fn();

Vue.use(VueApollo);

describe('ArtifactsTableRowDetails component', () => {
  let wrapper;
  let requestHandlers;

  const createComponent = (
    handlers = {
      destroyArtifactMutation: jest.fn(),
    },
  ) => {
    requestHandlers = handlers;
    wrapper = shallowMountExtended(ArtifactsTableRowDetails, {
      apolloProvider: createMockApollo([
        [destroyArtifactMutation, requestHandlers.destroyArtifactMutation],
      ]),
      propsData: {
        artifacts,
        refetchArtifacts,
        queryVariables: {},
      },
      data() {
        return { deletingArtifactId: null };
      },
      stubs: {
        RecycleScroller,
        DynamicScroller,
        ArtifactRow,
      },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('passes correct props', () => {
    beforeEach(() => {
      createComponent();
    });

    it('to the dynamic scroller', () => {
      expect(wrapper.findComponent(DynamicScroller).props()).toMatchObject({
        items: artifacts.nodes,
      });
    });

    it('to the artifact row', () => {
      expect(wrapper.findAllComponents(ArtifactRow).at(0).props()).toMatchObject({
        artifact: artifacts.nodes[0],
        isLoading: false,
      });
    });
  });

  describe('when an artifact row emits the delete event', () => {
    it('triggers the destroyArtifact GraphQL mutation', async () => {
      createComponent();
      await waitForPromises();

      wrapper.findComponent(ArtifactRow).vm.$emit('delete');

      expect(requestHandlers.destroyArtifactMutation).toHaveBeenCalled();
    });

    it('displays a flash message and refetches artifacts when the mutation fails', async () => {
      createComponent({
        destroyArtifactMutation: jest.fn().mockRejectedValue(new Error('Error!')),
      });
      await waitForPromises();

      wrapper.findComponent(ArtifactRow).vm.$emit('delete');
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith({ message: i18n.destroyArtifactError });
      expect(refetchArtifacts).toHaveBeenCalled();
    });
  });
});
