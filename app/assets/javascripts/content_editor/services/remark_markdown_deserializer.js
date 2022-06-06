import { isString } from 'lodash';
import { render } from '~/lib/gfm';
import { createProseMirrorDocFromMdastTree } from './hast_to_prosemirror_converter';

const isTaskItem = (hastNode) => {
  const { className } = hastNode.properties;

  return (
    hastNode.tagName === 'li' && Array.isArray(className) && className.includes('task-list-item')
  );
};

const getTableCellAttrs = (hastNode) => ({
  colspan: parseInt(hastNode.properties.colSpan, 10) || 1,
  rowspan: parseInt(hastNode.properties.rowSpan, 10) || 1,
});

const factorySpecs = {
  blockquote: { type: 'block', selector: 'blockquote' },
  paragraph: { type: 'block', selector: 'p' },
  listItem: {
    type: 'block',
    wrapTextInParagraph: true,
    processText: (text) => text.trim(),
    selector: (hastNode) => hastNode.tagName === 'li' && !hastNode.properties.className,
  },
  orderedList: {
    type: 'block',
    selector: (hastNode) => hastNode.tagName === 'ol' && !hastNode.properties.className,
  },
  bulletList: {
    type: 'block',
    selector: (hastNode) => hastNode.tagName === 'ul' && !hastNode.properties.className,
  },
  heading: {
    type: 'block',
    selector: (hastNode) => ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'].includes(hastNode.tagName),
    getAttrs: (hastNode) => {
      const level = parseInt(/(\d)$/.exec(hastNode.tagName)?.[1], 10) || 1;

      return { level };
    },
  },
  codeBlock: {
    type: 'block',
    skipChildren: true,
    selector: 'pre',
    getContent: ({ hastNodeText }) => hastNodeText.replace(/\n$/, ''),
    getAttrs: (hastNode) => {
      const languageClass = hastNode.children[0]?.properties.className?.[0];
      const language = isString(languageClass) ? languageClass.replace('language-', '') : null;

      return { language };
    },
  },
  horizontalRule: {
    type: 'block',
    selector: 'hr',
  },
  taskList: {
    type: 'block',
    selector: (hastNode) => {
      const { className } = hastNode.properties;

      return (
        ['ul', 'ol'].includes(hastNode.tagName) &&
        Array.isArray(className) &&
        className.includes('contains-task-list')
      );
    },
    getAttrs: (hastNode) => ({
      numeric: hastNode.tagName === 'ol',
    }),
  },
  taskItem: {
    type: 'block',
    wrapTextInParagraph: true,
    processText: (text) => text.trim(),
    selector: isTaskItem,
    getAttrs: (hastNode) => ({
      checked: hastNode.children[0].properties.checked,
    }),
  },
  taskItemCheckbox: {
    type: 'ignore',
    selector: (hastNode, ancestors) =>
      hastNode.tagName === 'input' && isTaskItem(ancestors[ancestors.length - 1]),
  },
  table: {
    type: 'block',
    selector: 'table',
  },
  tableRow: {
    type: 'block',
    selector: 'tr',
    parent: 'table',
  },
  tableHeader: {
    type: 'block',
    selector: 'th',
    getAttrs: getTableCellAttrs,
    wrapTextInParagraph: true,
  },
  tableCell: {
    type: 'block',
    selector: 'td',
    getAttrs: getTableCellAttrs,
    wrapTextInParagraph: true,
  },
  ignoredTableNodes: {
    type: 'ignore',
    selector: (hastNode) => ['thead', 'tbody', 'tfoot'].includes(hastNode.tagName),
  },
  image: {
    type: 'inline',
    selector: 'img',
    getAttrs: (hastNode) => ({
      src: hastNode.properties.src,
      title: hastNode.properties.title,
      alt: hastNode.properties.alt,
    }),
  },
  hardBreak: {
    type: 'inline',
    selector: 'br',
  },
  code: {
    type: 'mark',
    selector: 'code',
  },
  italic: {
    type: 'mark',
    selector: (hastNode) => ['em', 'i'].includes(hastNode.tagName),
  },
  bold: {
    type: 'mark',
    selector: (hastNode) => ['strong', 'b'].includes(hastNode.tagName),
  },
  link: {
    type: 'mark',
    selector: 'a',
    getAttrs: (hastNode) => ({
      href: hastNode.properties.href,
      title: hastNode.properties.title,
    }),
  },
  strike: {
    type: 'mark',
    selector: (hastNode) => ['strike', 's', 'del'].includes(hastNode.tagName),
  },
};

export default () => {
  return {
    deserialize: async ({ schema, content: markdown }) => {
      const document = await render({
        markdown,
        renderer: (tree) =>
          createProseMirrorDocFromMdastTree({
            schema,
            factorySpecs,
            tree,
            source: markdown,
          }),
      });

      return { document };
    },
  };
};
