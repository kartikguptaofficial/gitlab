import { shallowMount } from '@vue/test-utils';
import VueRouter from 'vue-router';
import Vue from 'vue';
import { GlBreadcrumb } from '@gitlab/ui';
import WorkspacesBreadcrumbs from 'ee/remote_development/components/common/workspaces_breadcrumbs.vue';
import createRouter from 'ee/remote_development/router';
import { s__ } from '~/locale';

describe('WorkspacesBreadcrumbs', () => {
  const base = '/-/remote_development/workspaces';

  const rootBreadcrumb = {
    text: s__('Workspaces|Workspaces'),
    to: 'index',
  };

  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let router;

  Vue.use(VueRouter);

  const findBreadcrumbs = () => wrapper.findComponent(GlBreadcrumb);

  const createWrapper = () => {
    router = createRouter(base);

    wrapper = shallowMount(WorkspacesBreadcrumbs, { router });
  };

  describe('when mounted', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render only the root breadcrumb when on the root route', async () => {
      try {
        await router.push('/');
      } catch {
        // intentionally blank
        //
        // * in Vue.js 3 we need to refresh even '/' route
        // because we dynamically add routes and exception will not be raised
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      expect(findBreadcrumbs().props('items')).toStrictEqual([rootBreadcrumb]);
    });

    it('should render only the root breadcrumb without sub routes', async () => {
      try {
        await router.push('/');
      } catch {
        // intentionally blank
        //
        // * in Vue.js 3 we need to refresh even '/' route
        // because we dynamically add routes and exception will not be raised
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      expect(findBreadcrumbs().props('items')).toStrictEqual([rootBreadcrumb]);
    });

    it('should render the root and dashboard new workspace', async () => {
      await router.push('new');

      expect(findBreadcrumbs().props('items')).toStrictEqual([
        rootBreadcrumb,
        {
          text: 'Create a new workspace',
          to: 'new',
        },
      ]);
    });
  });
});
