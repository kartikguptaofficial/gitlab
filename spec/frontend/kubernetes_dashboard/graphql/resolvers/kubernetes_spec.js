import { CoreV1Api, WatchApi } from '@gitlab/cluster-client';
import { resolvers } from '~/kubernetes_dashboard/graphql/resolvers';
import k8sDashboardPodsQuery from '~/kubernetes_dashboard/graphql/queries/k8s_dashboard_pods.query.graphql';
import { k8sPodsMock } from '../mock_data';

describe('~/frontend/environments/graphql/resolvers', () => {
  let mockResolvers;

  const configuration = {
    basePath: 'kas-proxy/',
    baseOptions: {
      headers: { 'GitLab-Agent-Id': '1' },
    },
  };

  beforeEach(() => {
    mockResolvers = resolvers;
  });

  describe('k8sPods', () => {
    const client = { writeQuery: jest.fn() };

    const mockWatcher = WatchApi.prototype;
    const mockPodsListWatcherFn = jest.fn().mockImplementation(() => {
      return Promise.resolve(mockWatcher);
    });

    const mockOnDataFn = jest.fn().mockImplementation((eventName, callback) => {
      if (eventName === 'data') {
        callback([]);
      }
    });

    const mockPodsListFn = jest.fn().mockImplementation(() => {
      return Promise.resolve({
        items: k8sPodsMock,
      });
    });

    const mockAllPodsListFn = jest.fn().mockImplementation(mockPodsListFn);

    describe('when the pods data is present', () => {
      beforeEach(() => {
        jest
          .spyOn(CoreV1Api.prototype, 'listCoreV1PodForAllNamespaces')
          .mockImplementation(mockAllPodsListFn);
        jest.spyOn(mockWatcher, 'subscribeToStream').mockImplementation(mockPodsListWatcherFn);
        jest.spyOn(mockWatcher, 'on').mockImplementation(mockOnDataFn);
      });

      it('should request all pods from the cluster_client library and watch the events', async () => {
        const pods = await mockResolvers.Query.k8sPods(
          null,
          {
            configuration,
          },
          { client },
        );

        expect(mockAllPodsListFn).toHaveBeenCalled();
        expect(mockPodsListWatcherFn).toHaveBeenCalled();

        expect(pods).toEqual(k8sPodsMock);
      });

      it('should update cache with the new data when received from the library', async () => {
        await mockResolvers.Query.k8sPods(null, { configuration, namespace: '' }, { client });

        expect(client.writeQuery).toHaveBeenCalledWith({
          query: k8sDashboardPodsQuery,
          variables: { configuration, namespace: '' },
          data: { k8sPods: [] },
        });
      });
    });

    it('should not watch pods from the cluster_client library when the pods data is not present', async () => {
      jest.spyOn(CoreV1Api.prototype, 'listCoreV1PodForAllNamespaces').mockImplementation(
        jest.fn().mockImplementation(() => {
          return Promise.resolve({
            items: [],
          });
        }),
      );

      await mockResolvers.Query.k8sPods(null, { configuration }, { client });

      expect(mockPodsListWatcherFn).not.toHaveBeenCalled();
    });

    it('should throw an error if the API call fails', async () => {
      jest
        .spyOn(CoreV1Api.prototype, 'listCoreV1PodForAllNamespaces')
        .mockRejectedValue(new Error('API error'));

      await expect(
        mockResolvers.Query.k8sPods(null, { configuration }, { client }),
      ).rejects.toThrow('API error');
    });
  });
});
