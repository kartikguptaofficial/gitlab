import Vue from 'vue';
import { initNamespaceCatalog } from 'ee/ci/catalog/index';
import * as Router from '~/ci/catalog/router';
import CiResourcesPage from 'ee/ci/catalog/components/pages/ci_resources_page.vue';

describe('ee/ci/catalog/index', () => {
  describe('initNamespaceCatalog', () => {
    const SELECTOR = 'SELECTOR';

    let el;
    let component;
    const baseRoute = '/ci/catalog/resources';

    const createElement = () => {
      el = document.createElement('div');
      el.id = SELECTOR;
      el.dataset.ciCatalogPath = baseRoute;
      document.body.appendChild(el);
    };

    afterEach(() => {
      el = null;
    });

    describe('when the element exists', () => {
      beforeEach(() => {
        createElement();
        jest.spyOn(Router, 'createRouter');
        component = initNamespaceCatalog(`#${SELECTOR}`);
      });

      it('returns a Vue Instance', () => {
        expect(component).toBeInstanceOf(Vue);
      });

      it('creates a router with the received base path and component', () => {
        expect(Router.createRouter).toHaveBeenCalledTimes(1);
        expect(Router.createRouter).toHaveBeenCalledWith(baseRoute, CiResourcesPage);
      });
    });

    describe('When the element does not exist', () => {
      it('returns `null`', () => {
        expect(initNamespaceCatalog('foo')).toBe(null);
      });
    });
  });
});
