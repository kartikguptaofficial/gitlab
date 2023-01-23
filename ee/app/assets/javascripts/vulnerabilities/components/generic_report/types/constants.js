import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';

export const REPORT_TYPES = {
  list: 'list',
  url: 'url',
  diff: 'diff',
  namedList: 'named-list',
  text: 'text',
  value: 'value',
  moduleLocation: 'module-location',
  fileLocation: 'file-location',
  table: 'table',
  code: 'code',
  markdown: 'markdown',
  commit: 'commit',
};

const REPORT_TYPE_TO_COMPONENT_MAP = {
  [REPORT_TYPES.list]: () => import('./list.vue'),
  [REPORT_TYPES.url]: () => import('./url.vue'),
  [REPORT_TYPES.diff]: () => import('./diff.vue'),
  [REPORT_TYPES.namedList]: () => import('./named_list.vue'),
  [REPORT_TYPES.text]: () => import('./value.vue'),
  [REPORT_TYPES.value]: () => import('./value.vue'),
  [REPORT_TYPES.moduleLocation]: () => import('./module_location.vue'),
  [REPORT_TYPES.fileLocation]: () => import('./file_location.vue'),
  [REPORT_TYPES.table]: () => import('./table.vue'),
  [REPORT_TYPES.code]: () => import('./code.vue'),
  [REPORT_TYPES.markdown]: () => import('./markdown.vue'),
  [REPORT_TYPES.commit]: () => import('./commit.vue'),
};

export const getComponentNameForType = (reportType) =>
  `ReportType${capitalizeFirstCharacter(reportType)}`;

export const REPORT_COMPONENTS = Object.fromEntries(
  Object.entries(REPORT_TYPE_TO_COMPONENT_MAP).map(([reportType, component]) => [
    getComponentNameForType(reportType),
    component,
  ]),
);

export const GRAPHQL_TYPENAME_URL = 'VulnerabilityDetailUrl';
export const GRAPHQL_TYPENAME_DIFF = 'VulnerabilityDetailDiff';
export const GRAPHQL_TYPENAME_CODE = 'VulnerabilityDetailCode';
export const GRAPHQL_TYPENAME_FILE_LOCATION = 'VulnerabilityDetailFileLocation';

export const GRAPHQL_TYPENAME_TO_COMPONENT_MAP = {
  [GRAPHQL_TYPENAME_URL]: () => import('./url.vue'),
  [GRAPHQL_TYPENAME_DIFF]: () => import('./diff.vue'),
  [GRAPHQL_TYPENAME_CODE]: () => import('./code.vue'),
  [GRAPHQL_TYPENAME_FILE_LOCATION]: () => import('./file_location.vue'),
};

export const GRAPHQL_TYPENAMES = Object.keys(GRAPHQL_TYPENAME_TO_COMPONENT_MAP);

/*
 * Diff component
 */
const DIFF = 'diff';
const BEFORE = 'before';
const AFTER = 'after';

export const VIEW_TYPES = { DIFF, BEFORE, AFTER };

const NORMAL = 'normal';
const REMOVED = 'removed';
const ADDED = 'added';

export const LINE_TYPES = { NORMAL, REMOVED, ADDED };
