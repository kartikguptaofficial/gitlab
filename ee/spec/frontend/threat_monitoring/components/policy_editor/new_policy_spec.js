import { GlPath } from '@gitlab/ui';
import * as urlUtils from '~/lib/utils/url_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/threat_monitoring/components/constants';
import { NAMESPACE_TYPES } from 'ee/threat_monitoring/constants';
import NewPolicy from 'ee/threat_monitoring/components/policy_editor/new_policy.vue';
import PolicySelection from 'ee/threat_monitoring/components/policy_editor/policy_selection.vue';
import PolicyEditor from 'ee/threat_monitoring/components/policy_editor/policy_editor_v2.vue';

describe('NewPolicy component', () => {
  let wrapper;

  const findPolicySelection = () => wrapper.findComponent(PolicySelection);
  const findPolicyEditor = () => wrapper.findComponent(PolicyEditor);
  const findPath = () => wrapper.findComponent(GlPath);

  const factory = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(NewPolicy, {
      propsData: {
        assignedPolicyProject: {},
        ...propsData,
      },
      provide,
      stubs: { GlPath: true },
    });
  };

  afterEach(() => {
    wrapper.destroy();
  });

  describe('when there is no type query parameter', () => {
    describe('projects', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: NAMESPACE_TYPES.PROJECT } });
      });

      it('should display the title correctly', () => {
        expect(wrapper.findByText(NewPolicy.i18n.titles.default).exists()).toBe(true);
      });

      it('should display the path items correctly', () => {
        expect(findPath().props('items')).toMatchObject([
          {
            selected: true,
            title: NewPolicy.i18n.choosePolicyType,
          },
          {
            disabled: true,
            selected: false,
            title: NewPolicy.i18n.policyDetails,
          },
        ]);
      });

      it('should display the correct view', () => {
        expect(findPolicySelection().exists()).toBe(true);
        expect(findPolicyEditor().exists()).toBe(false);
      });
    });

    describe('groups', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
      });

      it('should display the title correctly', () => {
        expect(wrapper.findByText(NewPolicy.i18n.titles.scanExecution).exists()).toBe(true);
      });

      it('should not display the GlPath component when there is an existing policy', () => {
        expect(findPath().exists()).toBe(false);
      });

      it('should display the correct view according to the selected policy', () => {
        expect(findPolicySelection().exists()).toBe(false);
        expect(findPolicyEditor().exists()).toBe(true);
      });
    });
  });

  describe('when there is a type query parameter', () => {
    beforeEach(() => {
      jest
        .spyOn(urlUtils, 'getParameterByName')
        .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS.scanResult.urlParameter);
      factory({
        propsData: {
          existingPolicy: {
            id: 'policy-id',
          },
        },
        provide: { namespaceType: NAMESPACE_TYPES.PROJECT },
      });
    });

    it('should display the title correctly', () => {
      expect(wrapper.findByText(NewPolicy.i18n.editTitles.scanResult).exists()).toBe(true);
    });

    it('should not display the GlPath component when there is an existing policy', () => {
      expect(findPath().exists()).toBe(false);
    });

    it('should display the correct view according to the selected policy', () => {
      expect(findPolicySelection().exists()).toBe(false);
      expect(findPolicyEditor().exists()).toBe(true);
    });
  });
});
