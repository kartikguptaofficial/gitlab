import axios from 'axios';
import Autosize from 'autosize';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import {
  EDITING_MODE_MARKDOWN_FIELD,
  EDITING_MODE_CONTENT_EDITOR,
  CLEAR_AUTOSAVE_ENTRY_EVENT,
} from '~/vue_shared/constants';
import markdownEditorEventHub from '~/vue_shared/components/markdown/eventhub';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import ContentEditor from '~/content_editor/components/content_editor.vue';
import BubbleMenu from '~/content_editor/components/bubble_menus/bubble_menu.vue';
import LocalStorageSync from '~/vue_shared/components/local_storage_sync.vue';
import MarkdownField from '~/vue_shared/components/markdown/field.vue';
import { assertProps } from 'helpers/assert_props';
import { stubComponent } from 'helpers/stub_component';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import waitForPromises from 'helpers/wait_for_promises';

jest.mock('~/emoji');
jest.mock('autosize');
jest.mock('~/lib/graphql');

describe('vue_shared/component/markdown/markdown_editor', () => {
  useLocalStorageSpy();

  let wrapper;
  const value = 'test markdown';
  const renderMarkdownPath = '/api/markdown';
  const markdownDocsPath = '/help/markdown';
  const enableAutocomplete = true;
  const enablePreview = false;
  const formFieldId = 'markdown_field';
  const formFieldName = 'form[markdown_field]';
  const formFieldPlaceholder = 'Write some markdown';
  const formFieldAriaLabel = 'Edit your content';
  const autocompleteDataSources = { commands: '/foobar/-/autcomplete_sources' };
  let mock;

  const defaultProps = {
    value,
    renderMarkdownPath,
    markdownDocsPath,
    enableAutocomplete,
    autocompleteDataSources,
    enablePreview,
    formFieldProps: {
      id: formFieldId,
      name: formFieldName,
      placeholder: formFieldPlaceholder,
      'aria-label': formFieldAriaLabel,
    },
  };
  const buildWrapper = ({ propsData = {}, attachTo, stubs = {} } = {}) => {
    wrapper = mountExtended(MarkdownEditor, {
      attachTo,
      propsData: {
        ...defaultProps,
        ...propsData,
      },
      stubs: {
        BubbleMenu: stubComponent(BubbleMenu),
        ...stubs,
      },
      mocks: {
        $apollo: {
          queries: {
            currentUser: {
              loading: false,
            },
          },
        },
      },
    });
  };

  const ContentEditorStub = stubComponent(ContentEditor);

  const findMarkdownField = () => wrapper.findComponent(MarkdownField);
  const findTextarea = () => wrapper.find('textarea');
  const findLocalStorageSync = () => wrapper.findComponent(LocalStorageSync);
  const findContentEditor = () => {
    const result = wrapper.findComponent(ContentEditor);

    // In Vue.js 3 there are nuances stubbing component with custom stub on mount
    // So we try to search for stub also
    return result.exists() ? result : wrapper.findComponent(ContentEditorStub);
  };

  const enableContentEditor = async () => {
    findMarkdownField().vm.$emit('enableContentEditor');
    await nextTick();
    await waitForPromises();
  };

  const enableMarkdownEditor = async () => {
    findContentEditor().vm.$emit('enableMarkdownEditor');
    await nextTick();
    await waitForPromises();
  };

  beforeEach(() => {
    window.uploads_path = 'uploads';
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();

    localStorage.clear();
  });

  it('displays markdown field by default', () => {
    buildWrapper({ propsData: { supportsQuickActions: true } });

    expect(findMarkdownField().props()).toMatchObject({
      autocompleteDataSources,
      markdownPreviewPath: renderMarkdownPath,
      supportsQuickActions: true,
      canAttachFile: true,
      enableAutocomplete,
      textareaValue: value,
      markdownDocsPath,
      uploadsPath: window.uploads_path,
      enablePreview,
    });
  });

  // quarantine: https://gitlab.com/gitlab-org/gitlab/-/issues/412618
  // eslint-disable-next-line jest/no-disabled-tests
  it.skip('passes render_quick_actions param to renderMarkdownPath if quick actions are enabled', async () => {
    buildWrapper({ propsData: { supportsQuickActions: true } });

    await enableContentEditor();

    expect(mock.history.post).toHaveLength(1);
    expect(mock.history.post[0].url).toContain(`render_quick_actions=true`);
  });

  // quarantine: https://gitlab.com/gitlab-org/gitlab/-/issues/411565
  // eslint-disable-next-line jest/no-disabled-tests
  it.skip('does not pass render_quick_actions param to renderMarkdownPath if quick actions are disabled', async () => {
    buildWrapper({ propsData: { supportsQuickActions: false } });

    await enableContentEditor();

    expect(mock.history.post).toHaveLength(1);
    expect(mock.history.post[0].url).toContain(`render_quick_actions=false`);
  });

  it('enables content editor switcher when contentEditorEnabled prop is true', () => {
    buildWrapper({ propsData: { enableContentEditor: true } });

    expect(findMarkdownField().text()).toContain('Switch to rich text editing');
  });

  it('hides content editor switcher when contentEditorEnabled prop is false', () => {
    buildWrapper({ propsData: { enableContentEditor: false } });

    expect(findMarkdownField().text()).not.toContain('Switch to rich text editing');
  });

  it('passes down any additional props to markdown field component', () => {
    const codeSuggestionsConfig = {
      line: { text: 'hello world', richText: 'hello world' },
      lines: [{ text: 'hello world', richText: 'hello world' }],
      canSuggest: true,
    };

    buildWrapper({
      propsData: {
        codeSuggestionsConfig,
        myCustomProp: 'myCustomValue',
        'data-testid': 'custom id',
      },
    });

    expect(findMarkdownField().props()).toMatchObject(codeSuggestionsConfig);
    expect(findMarkdownField().vm.$attrs).toMatchObject({
      myCustomProp: 'myCustomValue',

      // data-testid isn't copied over
      'data-testid': 'markdown-field',
    });
  });

  describe('when attachments are disabled', () => {
    beforeEach(() => {
      buildWrapper({ propsData: { disableAttachments: true } });
    });

    it('disables canAttachFile', () => {
      expect(findMarkdownField().props().canAttachFile).toBe(false);
    });

    it('passes `attach-file` to restrictedToolBarItems', () => {
      expect(findMarkdownField().props().restrictedToolBarItems).toContain('attach-file');
    });
  });

  describe('disabled', () => {
    it('disables markdown field when disabled prop is true', () => {
      buildWrapper({ propsData: { disabled: true } });

      expect(findMarkdownField().find('textarea').attributes('disabled')).toBeDefined();
    });

    it('enables markdown field when disabled prop is false', () => {
      buildWrapper({ propsData: { disabled: false } });

      expect(findMarkdownField().find('textarea').attributes('disabled')).toBe(undefined);
    });

    // quarantine: https://gitlab.com/gitlab-org/gitlab/-/issues/404734
    // eslint-disable-next-line jest/no-disabled-tests
    it.skip('disables content editor when disabled prop is true', async () => {
      buildWrapper({ propsData: { disabled: true } });

      await enableContentEditor();

      expect(findContentEditor().props('editable')).toBe(false);
    });

    it('enables content editor when disabled prop is false', async () => {
      buildWrapper({ propsData: { disabled: false } });

      await enableContentEditor();

      expect(findContentEditor().props('editable')).toBe(true);
    });
  });

  describe('autosize', () => {
    it('autosizes the textarea when the value changes', async () => {
      buildWrapper();
      await findTextarea().setValue('Lots of newlines\n\n\n\n\n\n\nMore content\n\n\nand newlines');
      await nextTick();
      expect(Autosize.update).toHaveBeenCalled();
    });

    it('autosizes the textarea when the value changes from outside the component', async () => {
      buildWrapper();
      wrapper.setProps({ value: 'Lots of newlines\n\n\n\n\n\n\nMore content\n\n\nand newlines' });

      await nextTick();
      await waitForPromises();
      expect(Autosize.update).toHaveBeenCalled();
    });

    it('does not autosize the textarea if markdown editor is disabled', async () => {
      buildWrapper();
      await enableContentEditor();

      wrapper.setProps({ value: 'Lots of newlines\n\n\n\n\n\n\nMore content\n\n\nand newlines' });

      expect(Autosize.update).not.toHaveBeenCalled();
    });
  });

  describe('autosave', () => {
    it('automatically saves the textarea value to local storage if autosaveKey is defined', () => {
      buildWrapper({ propsData: { autosaveKey: 'issue/1234', value: 'This is **markdown**' } });

      expect(localStorage.getItem('autosave/issue/1234')).toBe('This is **markdown**');
    });

    it("loads value from local storage if autosaveKey is defined, and value isn't", () => {
      localStorage.setItem('autosave/issue/1234', 'This is **markdown**');

      buildWrapper({ propsData: { autosaveKey: 'issue/1234', value: '' } });

      expect(findTextarea().element.value).toBe('This is **markdown**');
    });

    it("doesn't load value from local storage if autosaveKey is defined, and value is", () => {
      localStorage.setItem('autosave/issue/1234', 'This is **markdown**');

      buildWrapper({ propsData: { autosaveKey: 'issue/1234' } });

      expect(findTextarea().element.value).toBe('test markdown');
    });

    it('does not save the textarea value to local storage if autosaveKey is not defined', () => {
      buildWrapper({ propsData: { value: 'This is **markdown**' } });

      expect(localStorage.setItem).not.toHaveBeenCalled();
    });

    it('does not save the textarea value to local storage if value is empty', () => {
      buildWrapper({ propsData: { autosaveKey: 'issue/1234', value: '' } });

      expect(localStorage.setItem).not.toHaveBeenCalled();
    });

    describe('clear local storage event handler', () => {
      it('does not clear the local storage if the autosave key is not defined', async () => {
        buildWrapper();

        await waitForPromises();

        markdownEditorEventHub.$emit(CLEAR_AUTOSAVE_ENTRY_EVENT, 'issue/1234');

        expect(localStorage.removeItem).not.toHaveBeenCalled();
      });

      it('does not clear the local storage if the event autosave key does not match', async () => {
        buildWrapper({ propsData: { autosaveKey: 'issue/1234' } });

        await waitForPromises();

        markdownEditorEventHub.$emit(CLEAR_AUTOSAVE_ENTRY_EVENT, 'issue/1235');

        expect(localStorage.removeItem).not.toHaveBeenCalled();
      });

      it('clears the local storage if the event autosave key matches', async () => {
        buildWrapper({ propsData: { autosaveKey: 'issue/1234' } });

        await waitForPromises();

        markdownEditorEventHub.$emit(CLEAR_AUTOSAVE_ENTRY_EVENT, 'issue/1234');

        expect(localStorage.removeItem).toHaveBeenCalledWith('autosave/issue/1234');
      });
    });
  });

  it('renders markdown field textarea', () => {
    buildWrapper({ propsData: { supportsQuickActions: true } });

    expect(findTextarea().attributes()).toEqual(
      expect.objectContaining({
        id: formFieldId,
        name: formFieldName,
        placeholder: formFieldPlaceholder,
        'aria-label': formFieldAriaLabel,
        'data-supports-quick-actions': 'true',
      }),
    );

    expect(findTextarea().element.value).toBe(value);
  });

  it('fails to render if textarea id and name is not passed', () => {
    expect(() => assertProps(MarkdownEditor, { ...defaultProps, formFieldProps: {} })).toThrow(
      'Invalid prop: custom validator check failed for prop "formFieldProps"',
    );
  });

  it(`emits ${EDITING_MODE_CONTENT_EDITOR} event when enableContentEditor emitted from markdown editor`, async () => {
    buildWrapper();

    await enableContentEditor();

    expect(wrapper.emitted(EDITING_MODE_CONTENT_EDITOR)).toHaveLength(1);
  });

  it(`emits ${EDITING_MODE_MARKDOWN_FIELD} event when enableMarkdownEditor emitted from content editor`, async () => {
    buildWrapper({
      stubs: { ContentEditor: ContentEditorStub },
    });

    await enableContentEditor();
    await enableMarkdownEditor();

    expect(wrapper.emitted(EDITING_MODE_MARKDOWN_FIELD)).toHaveLength(1);
  });

  describe(`when editingMode is ${EDITING_MODE_MARKDOWN_FIELD}`, () => {
    it('emits input event when markdown field textarea changes', async () => {
      buildWrapper();
      const newValue = 'new value';

      await findTextarea().setValue(newValue);

      expect(wrapper.emitted('input')).toEqual([[value], [newValue]]);
    });

    it('autosaves the markdown value to local storage', async () => {
      buildWrapper({ propsData: { autosaveKey: 'issue/1234' } });

      const newValue = 'new value';

      await findTextarea().setValue(newValue);

      expect(localStorage.getItem('autosave/issue/1234')).toBe(newValue);
    });

    describe('when autofocus is true', () => {
      beforeEach(async () => {
        buildWrapper({ attachTo: document.body, propsData: { autofocus: true } });

        await nextTick();
      });

      it('sets the markdown field as the active element in the document', () => {
        expect(document.activeElement).toBe(findTextarea().element);
      });
    });

    it('bubbles up keydown event', async () => {
      buildWrapper();

      await findTextarea().trigger('keydown');

      expect(wrapper.emitted('keydown')).toHaveLength(1);
    });

    describe(`when markdown field triggers enableContentEditor event`, () => {
      beforeEach(async () => {
        buildWrapper();
        await enableContentEditor();
      });

      it('displays the content editor', () => {
        expect(findContentEditor().props()).toEqual(
          expect.objectContaining({
            renderMarkdown: expect.any(Function),
            uploadsPath: window.uploads_path,
            markdown: value,
          }),
        );
      });

      it('adds hidden field with current markdown', () => {
        const hiddenField = wrapper.find(`#${formFieldId}`);

        expect(hiddenField.attributes()).toEqual(
          expect.objectContaining({
            id: formFieldId,
            name: formFieldName,
          }),
        );
        expect(hiddenField.element.value).toBe(value);
      });

      it('hides the markdown field', () => {
        expect(findMarkdownField().exists()).toBe(false);
      });

      it('updates localStorage value', () => {
        expect(findLocalStorageSync().props().value).toBe(EDITING_MODE_CONTENT_EDITOR);
      });
    });
  });

  describe('when contentEditor is disabled', () => {
    it('resets the editingMode to markdownField', () => {
      buildWrapper({ propsData: { autosaveKey: 'issue/1234', enableContentEditor: false } });

      expect(wrapper.vm.editingMode).toBe(EDITING_MODE_MARKDOWN_FIELD);
    });
  });

  describe(`when editingMode is ${EDITING_MODE_CONTENT_EDITOR}`, () => {
    beforeEach(async () => {
      buildWrapper({ propsData: { autosaveKey: 'issue/1234' } });
      await enableContentEditor();
    });

    describe('when autofocus is true', () => {
      beforeEach(() => {
        buildWrapper({
          propsData: { autofocus: true },
          stubs: { ContentEditor: ContentEditorStub },
        });
      });

      it('sets the content editor autofocus property to end', () => {
        expect(findContentEditor().props().autofocus).toBe('end');
      });
    });

    it('emits input event when content editor emits change event', async () => {
      const newValue = 'new value';

      await findContentEditor().vm.$emit('change', { markdown: newValue });

      expect(wrapper.emitted('input')).toEqual([[value], [newValue]]);
    });

    it('autosaves the content editor value to local storage', async () => {
      const newValue = 'new value';

      await findContentEditor().vm.$emit('change', { markdown: newValue });

      expect(localStorage.getItem('autosave/issue/1234')).toBe(newValue);
    });

    it('does not autofocus the content editor', () => {
      buildWrapper({ propsData: { autosaveKey: 'issue/1234' } });
      expect(findContentEditor().props().autofocus).toBe(false);
    });

    describe('when keydown event is fired', () => {
      let event;
      beforeEach(() => {
        event = new Event('keydown');
        window.getSelection = jest.fn(() => ({
          toString: jest.fn(() => 'test'),
          removeAllRanges: jest.fn(),
        }));
        Object.assign(event, { preventDefault: jest.fn() });
      });
      it('bubbles up keydown event', () => {
        findContentEditor().vm.$emit('keydown', event);

        expect(wrapper.emitted('keydown')).toEqual([[event]]);
      });

      it('bubbles up keydown event for meta key with default behaviour intact', () => {
        event.metaKey = true;
        findContentEditor().vm.$emit('keydown', event);

        expect(wrapper.emitted('keydown')).toEqual([[event]]);
        expect(event.preventDefault).toHaveBeenCalledTimes(0);
      });

      it('bubbles up keydown event for meta + k key on selected text with default behaviour prevented', () => {
        event.metaKey = true;
        event.key = 'k';
        findContentEditor().vm.$emit('keydown', event);

        expect(wrapper.emitted('keydown')).toEqual([[event]]);
        expect(event.preventDefault).toHaveBeenCalledTimes(1);
      });

      it('bubbles up keydown event for meta + k key without text selection with default behaviour prevented', () => {
        event.metaKey = true;
        event.key = 'k';
        window.getSelection = jest.fn(() => ({
          toString: jest.fn(() => ''),
          removeAllRanges: jest.fn(),
        }));

        findContentEditor().vm.$emit('keydown', event);

        expect(wrapper.emitted('keydown')).toEqual([[event]]);
        expect(event.preventDefault).toHaveBeenCalledTimes(1);
      });

      it('bubbles up keydown event for meta + non-k key with default behaviour intact', () => {
        event.metaKey = true;
        event.key = 'l';

        findContentEditor().vm.$emit('keydown', event);

        expect(wrapper.emitted('keydown')).toEqual([[event]]);
        expect(event.preventDefault).toHaveBeenCalledTimes(0);
      });
    });

    describe(`when richText editor triggers enableMarkdownEditor event`, () => {
      beforeEach(enableMarkdownEditor);

      it('hides the content editor', () => {
        expect(findContentEditor().exists()).toBe(false);
      });

      it('shows the markdown field', () => {
        expect(findMarkdownField().exists()).toBe(true);
      });

      it('updates localStorage value', () => {
        expect(findLocalStorageSync().props().value).toBe(EDITING_MODE_MARKDOWN_FIELD);
      });
    });
  });
});
