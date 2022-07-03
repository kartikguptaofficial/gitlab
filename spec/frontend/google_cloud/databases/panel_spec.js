import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import Panel from '~/google_cloud/databases/panel.vue';

describe('google_cloud/databases/panel', () => {
  let wrapper;

  const props = {
    configurationUrl: 'configuration-url',
    deploymentsUrl: 'deployments-url',
    databasesUrl: 'databases-url',
  };

  beforeEach(() => {
    wrapper = shallowMountExtended(Panel, { propsData: props });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('contains incubation banner', () => {
    const target = wrapper.findByTestId('incubation-banner');
    expect(target.exists()).toBe(true);
  });

  it('contains google cloud menu with `databases` active', () => {
    const target = wrapper.findByTestId('google-cloud-menu');
    expect(target.exists()).toBe(true);
    expect(target.props('active')).toBe('databases');
    expect(target.props('configurationUrl')).toBe(props.configurationUrl);
    expect(target.props('deploymentsUrl')).toBe(props.deploymentsUrl);
    expect(target.props('databasesUrl')).toBe(props.databasesUrl);
  });
});
