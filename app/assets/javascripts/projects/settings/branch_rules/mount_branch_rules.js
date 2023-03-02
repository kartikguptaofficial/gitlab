import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createDefaultClient from '~/lib/graphql';
import { parseBoolean } from '~/lib/utils/common_utils';
import View from 'ee_else_ce/projects/settings/branch_rules/components/view/index.vue';

export default function mountBranchRules(el) {
  if (!el) {
    return null;
  }

  Vue.use(VueApollo);

  const apolloProvider = new VueApollo({
    defaultClient: createDefaultClient(),
  });

  const {
    projectPath,
    protectedBranchesPath,
    approvalRulesPath,
    statusChecksPath,
    branchesPath,
    showStatusChecks,
    showApprovers,
    showCodeOwners,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      projectPath,
      protectedBranchesPath,
      approvalRulesPath,
      statusChecksPath,
      branchesPath,
      showStatusChecks: parseBoolean(showStatusChecks),
      showApprovers: parseBoolean(showApprovers),
      showCodeOwners: parseBoolean(showCodeOwners),
    },
    render(h) {
      return h(View);
    },
  });
}
