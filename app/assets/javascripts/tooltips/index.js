import Vue from 'vue';
import Tooltips from './components/tooltips.vue';

let app;

const EVENTS_MAP = {
  hover: 'mouseenter',
  click: 'click',
  focus: 'focus',
};

const DEFAULT_TRIGGER = 'hover focus';

const tooltipsApp = () => {
  if (!app) {
    app = new Vue({
      render(h) {
        return h(Tooltips, {
          props: {
            elements: this.elements,
          },
          ref: 'tooltips',
        });
      },
    }).$mount();
  }

  return app;
};

const isTooltip = (node, selector) => node.matches && node.matches(selector);

const addTooltips = (elements, config) => {
  tooltipsApp().$refs.tooltips.addTooltips(Array.from(elements), config);
};

const handleTooltipEvent = (rootTarget, e, selector, config = {}) => {
  for (let { target } = e; target && target !== rootTarget; target = target.parentNode) {
    if (isTooltip(target, selector)) {
      addTooltips([target], {
        show: true,
        ...config,
      });
      break;
    }
  }
};

export const initTooltips = (selector, config = {}) => {
  const triggers = config?.triggers || DEFAULT_TRIGGER;
  const events = triggers.split(' ').map(trigger => EVENTS_MAP[trigger]);

  events.forEach(event => {
    document.addEventListener(event, e => handleTooltipEvent(document, e, selector, config), true);
  });

  return tooltipsApp();
};
