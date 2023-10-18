import { GlPopover, GlIcon, GlLink } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import AutoFixHelpText from 'ee/security_dashboard/components/shared/auto_fix_help_text.vue';

const TEST_MERGE_REQUEST_DATA = {
  webUrl: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/48820',
  state: 'merged',
  securityAutoFix: true,
  iid: 48820,
};

describe('AutoFix Help Text component', () => {
  let wrapper;
  const createWrapper = (mergeRequestProps) => {
    return mount(AutoFixHelpText, {
      propsData: {
        mergeRequest: { ...TEST_MERGE_REQUEST_DATA, ...mergeRequestProps },
      },
      stubs: {
        GlPopover: true,
      },
    });
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  const findPopover = () => wrapper.findComponent(GlPopover);
  const findLink = () => wrapper.findComponent(GlLink);

  it('popover should have wrapping div as target', () => {
    expect(findPopover().props('target')()).toBe(wrapper.element);
  });

  it('popover should contain Icon with passed status', () => {
    expect(findPopover().findComponent(GlIcon).props('name')).toBe('merge');
  });

  it('popover should contain Link with passed href', () => {
    expect(findLink().attributes('href')).toBe(TEST_MERGE_REQUEST_DATA.webUrl);
  });

  it.each`
    securityAutoFix | expectedText
    ${true}         | ${'!48820: Auto-fix'}
    ${false}        | ${'!48820'}
  `(
    'popover should contain merge request ID with text "$expectedText"',
    ({ securityAutoFix, expectedText }) => {
      wrapper = createWrapper({ securityAutoFix });
      expect(findLink().text()).toBe(expectedText);
    },
  );
});
