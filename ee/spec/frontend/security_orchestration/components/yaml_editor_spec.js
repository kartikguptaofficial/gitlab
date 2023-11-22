import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import { nextTick } from 'vue';
import YamlEditor from 'ee/security_orchestration/components/yaml_editor.vue';
import axios from '~/lib/utils/axios_utils';
import SourceEditor from '~/vue_shared/components/source_editor.vue';
import { EDITOR_READY_EVENT } from '~/editor/constants';

jest.mock('ee/security_orchestration/components/policy_editor_schema_ext', () => {
  const { PolicySchemaExtension } = jest.requireActual(
    'ee/security_orchestration/components/policy_editor_schema_ext',
  );
  return {
    PolicySchemaExtension: class extends PolicySchemaExtension {
      // eslint-disable-next-line class-methods-use-this
      provides() {
        return {
          registerSecurityPolicySchema() {},
        };
      }
    },
  };
});

describe('YamlEditor component', () => {
  let wrapper;

  let editorInstanceDetail;
  let mockEditorInstance;
  let mockRegisterSecurityPolicySchema;
  let mockUse;
  let mock;

  const mockNamespacePath = 'test/path';
  const mockNamespaceType = 'testType';
  const mockPolicyType = 'testPolicyType';

  const findEditor = () => wrapper.findComponent(SourceEditor);

  const factory = ({ propsData } = {}) => {
    wrapper = shallowMount(YamlEditor, {
      propsData: {
        value: 'foo',
        policyType: mockPolicyType,
        ...propsData,
      },
      provide: {
        namespacePath: mockNamespacePath,
        namespaceType: mockNamespaceType,
      },
      stubs: {
        SourceEditor,
      },
    });
  };

  beforeEach(() => {
    mock = new MockAdapter(axios);
    mockUse = jest.fn();
    mockRegisterSecurityPolicySchema = jest.fn();
    mockEditorInstance = {
      use: mockUse,
      registerSecurityPolicySchema: mockRegisterSecurityPolicySchema,
    };
    editorInstanceDetail = {
      detail: {
        instance: mockEditorInstance,
      },
    };
    factory();
  });

  afterEach(() => {
    mock.restore();
  });

  it('renders container element', () => {
    expect(findEditor().exists()).toBe(true);
  });

  it('initializes monaco editor with yaml language and provided value', () => {
    const editorComponent = findEditor();
    expect(editorComponent.props('value')).toBe('foo');
    const editor = editorComponent.vm.getEditor();
    expect(editor.getModel().getLanguageId()).toBe('yaml');
  });

  it("emits input event on editor's input", async () => {
    const editor = findEditor();
    editor.vm.$emit('input', 'foo');
    await nextTick();
    expect(wrapper.emitted().input).toEqual([['foo']]);
  });

  it('configures editor with syntax highlighting', () => {
    findEditor().vm.$emit(EDITOR_READY_EVENT, editorInstanceDetail);

    expect(mockUse).toHaveBeenCalledTimes(1);
    expect(mockRegisterSecurityPolicySchema).toHaveBeenCalledTimes(1);
    expect(mockRegisterSecurityPolicySchema).toHaveBeenCalledWith({
      namespacePath: mockNamespacePath,
      namespaceType: mockNamespaceType,
      policyType: mockPolicyType,
    });
  });

  it('should disable schema registration', () => {
    factory({
      propsData: {
        disableSchema: true,
      },
    });

    expect(mockUse).toHaveBeenCalledTimes(0);
    expect(mockRegisterSecurityPolicySchema).toHaveBeenCalledTimes(0);
  });

  it('configures source editor with unique id', () => {
    factory({
      propsData: {
        fileGlobalId: 'testId',
      },
    });

    expect(findEditor().props('fileGlobalId')).toBe('testId');
  });
});
