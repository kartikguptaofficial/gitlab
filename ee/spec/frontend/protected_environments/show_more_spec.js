import { mountExtended } from 'helpers/vue_test_utils_helper';
import { __ } from '~/locale';
import ShowMore from 'ee/protected_environments/show_more.vue';

describe('ee/protected_environments/show_more.vue', () => {
  let wrapper;

  const createWrapper = (propsData) =>
    mountExtended(ShowMore, {
      propsData,
      scopedSlots: {
        default: '<div :data-testid="props.item">{{props.item}}</div>',
      },
    });

  const findButton = () => wrapper.findByRole('button');

  describe('items less than limit', () => {
    let items;
    let limit;

    beforeEach(() => {
      items = ['foo', 'bar', 'baz'];
      limit = 5;

      wrapper = createWrapper({ items, limit });
    });

    it('shows the default slot, passing the item to its scope', () => {
      items.forEach((item) => {
        expect(wrapper.findByTestId(item).exists()).toBe(true);
      });
    });

    it('hides the "Show more" button', () => {
      expect(findButton().exists()).toBe(false);
    });
  });

  describe('items same as limit', () => {
    let items;
    let limit;

    beforeEach(() => {
      items = ['foo', 'bar', 'baz'];
      limit = 3;

      wrapper = createWrapper({ items, limit });
    });

    it('shows the default slot, passing the item to its scope', () => {
      items.forEach((item) => {
        expect(wrapper.findByTestId(item).exists()).toBe(true);
      });
    });

    it('hides the "Show more" button', () => {
      expect(findButton().exists()).toBe(false);
    });
  });

  describe('items more than limit', () => {
    let items;
    let limit;
    let button;

    beforeEach(() => {
      items = ['foo', 'bar', 'baz'];
      limit = 2;

      wrapper = createWrapper({ items, limit });

      button = findButton();
    });

    it('shows the default slot, passing the item to its scope until limit', () => {
      items.slice(0, limit).forEach((item) => {
        expect(wrapper.findByTestId(item).exists()).toBe(true);
      });
      items.slice(limit).forEach((item) => {
        expect(wrapper.findByTestId(item).exists()).toBe(false);
      });
    });

    it('shows the "Show more" button', () => {
      expect(button.text()).toBe(__('Show more'));
    });

    describe('after clicking', () => {
      beforeEach(() => {
        button.trigger('click');
      });

      it('shows the "Show less" button after clicking', async () => {
        expect(button.text()).toBe(__('Show less'));
      });

      it('shows all items after clicking', async () => {
        items.forEach((item) => {
          expect(wrapper.findByTestId(item).exists()).toBe(true);
        });
      });

      describe('and clicking again', () => {
        beforeEach(() => {
          button.trigger('click');
        });

        it('shows the default slot, passing the item to its scope until limit', () => {
          items.slice(0, limit).forEach((item) => {
            expect(wrapper.findByTestId(item).exists()).toBe(true);
          });
          items.slice(limit).forEach((item) => {
            expect(wrapper.findByTestId(item).exists()).toBe(false);
          });
        });

        it('shows the "Show more" button', () => {
          expect(button.text()).toBe(__('Show more'));
        });
      });
    });
  });
});
