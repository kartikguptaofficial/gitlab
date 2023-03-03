import { GlDropdown, GlSearchBoxByType, GlLoadingIcon } from '@gitlab/ui';
import { nextTick } from 'vue';
import FilterBody from 'ee/security_dashboard/components/shared/filters/filter_body.vue';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended } from 'helpers/vue_test_utils_helper';

describe('Filter Body component', () => {
  let wrapper;
  const focusInputMock = jest.fn();

  const defaultProps = {
    name: 'Some Name',
    selectedOptions: [],
  };

  const createComponent = (props, options) => {
    wrapper = mountExtended(FilterBody, {
      propsData: { ...defaultProps, ...props },
      stubs: {
        GlSearchBoxByType: stubComponent(GlSearchBoxByType, {
          methods: { focusInput: focusInputMock },
        }),
      },
      ...options,
    });
  };

  const dropdown = () => wrapper.findComponent(GlDropdown);
  const dropdownButton = () => wrapper.find('.dropdown-toggle');
  const searchBox = () => wrapper.findComponent(GlSearchBoxByType);
  const findStrongText = () => wrapper.findByTestId('name');

  it('shows the correct label name and dropdown header name', () => {
    createComponent();

    expect(findStrongText().text()).toBe(defaultProps.name);
    expect(dropdown().props('headerText')).toBe(defaultProps.name);
  });

  it('emits dropdown-show event when dropdown is shown', () => {
    createComponent();
    dropdown().vm.$emit('show');

    expect(wrapper.emitted('dropdown-show')).toHaveLength(1);
  });

  it('emits dropdown-hide event when dropdown is hidden', () => {
    createComponent();
    dropdown().vm.$emit('hide');

    expect(wrapper.emitted('dropdown-hide')).toHaveLength(1);
  });

  describe('dropdown button', () => {
    it('shows the selected option name if only one option is selected', () => {
      const option = { name: 'Some Selected Option' };
      createComponent({ selectedOptions: [option] });

      expect(dropdownButton().text()).toBe(option.name);
    });

    it('shows the selected option name and "+x more" if more than one option is selected', () => {
      const options = [{ name: 'Option 1' }, { name: 'Option 2' }, { name: 'Option 3' }];
      createComponent({ selectedOptions: options });

      expect(dropdownButton().text()).toMatchInterpolatedText('Option 1 +2 more');
    });
  });

  describe('search box', () => {
    it.each([true, false])('shows/hides search box when the showSearchBox prop is %s', (show) => {
      createComponent({ showSearchBox: show });

      expect(searchBox().exists()).toBe(show);
    });

    it('is focused when the dropdown is opened', async () => {
      createComponent({ showSearchBox: true }, { attachTo: document.body });
      dropdown().vm.$emit('show');
      await nextTick();

      expect(focusInputMock).toHaveBeenCalledTimes(1);
    });

    it('emits input event on component when search box input is changed', async () => {
      const text = 'abc';
      createComponent({ showSearchBox: true });
      searchBox().vm.$emit('input', text);
      await nextTick();

      expect(wrapper.emitted('input')[0][0]).toBe(text);
    });
  });

  describe('dropdown body', () => {
    it('shows slot content', () => {
      const slotContent = 'some slot content';
      createComponent({}, { slots: { default: slotContent } });

      expect(wrapper.text()).toContain(slotContent);
    });

    it('shows no matching results text if there is no slot content', () => {
      createComponent();

      expect(wrapper.text()).toContain('No matching results');
    });
  });

  describe('loading icon', () => {
    it.each`
      phrase     | loading
      ${'shows'} | ${true}
      ${'hides'} | ${false}
    `('$phrase the loading icon when the loading prop is $loading', ({ loading }) => {
      createComponent({ loading });

      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(loading);
    });
  });
});
