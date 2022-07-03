import { mountExtended } from 'helpers/vue_test_utils_helper';
import GoogleCloudMenu from '~/google_cloud/components/google_cloud_menu.vue';

describe('google_cloud/components/google_cloud_menu', () => {
  let wrapper;

  const props = {
    active: 'configuration',
    configurationUrl: 'configuration-url',
    deploymentsUrl: 'deployments-url',
    databasesUrl: 'databases-url',
  };

  beforeEach(() => {
    wrapper = mountExtended(GoogleCloudMenu, { propsData: props });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  it('contains configuration link', () => {
    const link = wrapper.findByTestId('configurationLink');
    expect(link.text()).toContain(GoogleCloudMenu.i18n.configuration.title);
    expect(link.attributes('href')).toContain(props.configurationUrl);
  });

  it('contains deployments link', () => {
    const link = wrapper.findByTestId('deploymentsLink');
    expect(link.text()).toContain(GoogleCloudMenu.i18n.deployments.title);
    expect(link.attributes('href')).toContain(props.deploymentsUrl);
  });

  it('contains databases link', () => {
    const link = wrapper.findByTestId('databasesLink');
    expect(link.text()).toContain(GoogleCloudMenu.i18n.databases.title);
    expect(link.attributes('href')).toContain(props.databasesUrl);
  });
});
