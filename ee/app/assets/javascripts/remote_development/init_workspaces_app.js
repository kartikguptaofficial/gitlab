import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import WorkspacesBreadcrumbs from './components/common/workspaces_breadcrumbs.vue';
import App from './pages/app.vue';
import createRouter from './router/index';

Vue.use(VueApollo);

const createApolloProvider = () => {
  const defaultClient = createDefaultClient();

  return new VueApollo({ defaultClient });
};

const initWorkspacesApp = () => {
  const el = document.querySelector('#js-workspaces');

  if (!el) {
    return null;
  }

  const { workspacesListPath, emptyStateSvgPath } = el.dataset;
  const router = createRouter({
    base: workspacesListPath,
  });
  injectVueAppBreadcrumbs(router, WorkspacesBreadcrumbs);
  return new Vue({
    el,
    name: 'WorkspacesRoot',
    router,
    apolloProvider: createApolloProvider(),
    provide: {
      workspacesListPath,
      emptyStateSvgPath,
    },
    render: (createElement) => createElement(App),
  });
};

export { initWorkspacesApp };
