import { GlButton, GlSkeletonLoader, GlBadge, GlIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import AiGenieChat from 'ee/ai/components/ai_genie_chat.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CodeBlockHighlighted from '~/vue_shared/components/code_block_highlighted.vue';
import { i18n, FEEDBACK_LINK_URL } from 'ee/ai/constants';

describe('AiGenieChat', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiGenieChat, {
      propsData: {
        ...props,
      },
    });
  };

  const findChatComponent = () => wrapper.findByTestId('chat-component');
  const findCloseButton = () => wrapper.findComponent(GlButton);
  const findSceletonLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findSelectedText = () => wrapper.findComponent(CodeBlockHighlighted);
  const findChatContent = () => wrapper.findByTestId('chat-content');
  const findAlert = () => wrapper.findByTestId('chat-error');
  const findGeneratedByAI = () => wrapper.findByText(i18n.GENIE_CHAT_LEGAL_GENERATED_BY_AI);
  const findWarning = () => wrapper.findByTestId('chat-legal-warning');
  const findBadge = () => wrapper.findComponent(GlBadge);
  const findFeedbackLink = () => wrapper.findByTestId('feedback-link');
  const findLinkIcon = () => findFeedbackLink().findComponent(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  describe('component with default props', () => {
    it('renders chat component', () => {
      expect(findChatComponent().exists()).toBe(true);
    });
    it('does not not render skeleton', () => {
      expect(findSceletonLoader().exists()).toBe(false);
    });
    it('does not not render alert', () => {
      expect(findAlert().exists()).toBe(false);
    });
    it('renders "text" as a default language', () => {
      const defaultLanguage = 'text';
      expect(findSelectedText().props('language')).toBe(defaultLanguage);
    });
    it('renders Experiment label', () => {
      const badgeType = 'info';
      const badgeSize = 'md';
      expect(findBadge().props('variant')).toBe(badgeType);
      expect(findBadge().props('size')).toBe(badgeSize);
      expect(findBadge().text()).toBe(i18n.EXPERIMENT_BADGE);
    });
    it('renders link to feedabck issue', () => {
      const iconName = 'comment';
      expect(findFeedbackLink().attributes('href')).toBe(FEEDBACK_LINK_URL);
      expect(findFeedbackLink().text()).toBe(i18n.FEEDBACK_LINK);
      expect(findLinkIcon().props('name')).toBe(iconName);
    });
  });

  it('is hidden after the header button is clicked', async () => {
    findCloseButton().vm.$emit('click');
    await nextTick();
    expect(findChatComponent().exists()).toBe(false);
  });

  it('renders skeleton when isLoading', () => {
    createComponent({ isLoading: true });
    expect(findSceletonLoader().exists()).toBe(true);
  });

  it('renders alert if error', () => {
    const errorMessage = 'Something went Wrong';
    createComponent({ error: errorMessage });
    expect(findAlert().text()).toBe(errorMessage);
  });

  it('renders content once content is passed', () => {
    const content = 'This is some nice content';
    createComponent({ content });
    expect(findChatContent().text()).toBe(content);
  });

  it('renders selectedText', () => {
    const selectedText = 'Text to explain';
    createComponent({ selectedText });
    expect(findSelectedText().props('code')).toBe(selectedText);
  });

  it('updates language once new value is passed', () => {
    const snippetLanguage = 'vue';
    createComponent({ snippetLanguage });
    expect(findSelectedText().props('language')).toBe(snippetLanguage);
  });

  it('renders a generated by AI note', () => {
    createComponent();
    expect(findGeneratedByAI().exists()).toBe(true);
  });

  it('renders a legal warning when rendered', () => {
    createComponent();
    expect(findWarning().exists()).toBe(true);
  });
});
