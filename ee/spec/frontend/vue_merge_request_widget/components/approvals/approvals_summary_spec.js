import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { mount } from '@vue/test-utils';
import approvalRulesResponse from 'test_fixtures/graphql/merge_requests/approvals/approvals.query.graphql_approval_rules.json';
import approvalsRequiredResponse from 'test_fixtures/graphql/merge_requests/approvals/approvals.query.graphql_approvals_required.json';
import { toNounSeriesText } from '~/lib/utils/grammar';
import ApprovalsSummary from '~/vue_merge_request_widget/components/approvals/approvals_summary.vue';

const TEST_APPROVALS_LEFT = 3;

Vue.use(VueApollo);

describe('MRWidget approvals summary', () => {
  let wrapper;

  const createComponent = (response = approvalRulesResponse) => {
    wrapper = mount(ApprovalsSummary, {
      propsData: {
        approvalState: response.data.project.mergeRequest,
        multipleApprovalRulesAvailable: true,
      },
    });
  };

  describe('when not approved', () => {
    beforeEach(async () => {
      createComponent();

      await nextTick();
    });

    it('renders message', () => {
      const names = toNounSeriesText(
        approvalRulesResponse.data.project.mergeRequest.approvalState.rules.map((r) => r.name),
      );

      expect(wrapper.text()).toContain(`Requires ${TEST_APPROVALS_LEFT} approvals from ${names}.`);
    });
  });

  describe('when no rulesLeft', () => {
    beforeEach(async () => {
      createComponent(approvalsRequiredResponse);

      await nextTick();
    });

    it('renders message', () => {
      expect(wrapper.text()).toContain(
        `Requires ${TEST_APPROVALS_LEFT} approvals from eligible users`,
      );
    });
  });
});
