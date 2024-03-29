import { intersection } from 'lodash';
import { isValidCron } from 'cron-validator';
import { sprintf } from '~/locale';
import createPolicyProject from 'ee/security_orchestration/graphql/mutations/create_policy_project.mutation.graphql';
import createScanExecutionPolicy from 'ee/security_orchestration/graphql/mutations/create_scan_execution_policy.mutation.graphql';
import { gqClient } from 'ee/security_orchestration/utils';
import createMergeRequestMutation from '~/graphql_shared/mutations/create_merge_request.mutation.graphql';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';

import {
  BRANCHES_KEY,
  BRANCH_TYPE_KEY,
  DEFAULT_MR_TITLE,
  PRIMARY_POLICY_KEYS,
  RULE_MODE_SCANNERS,
  SECURITY_POLICY_ACTIONS,
  ALL_SELECTED_LABEL,
  SELECTED_ITEMS_LABEL,
  MULTIPLE_SELECTED_LABEL,
} from './constants';

/**
 * Checks if an error exists and throws it if it does
 * @param {Object} payload contains the errors if they exist
 */
const checkForErrors = ({ errors, validationErrors }) => {
  if (errors?.length) {
    throw new Error(errors.join('\n'), { cause: validationErrors });
  }
};

/**
 * Creates a merge request for the changes to the policy file
 * @param {Object} payload contains the path to the parent project, the branch to merge on the project, and the branch to merge into
 * @returns {Object} contains the id of the merge request and any errors
 */
const createMergeRequest = async ({ projectPath, sourceBranch, targetBranch }) => {
  const input = {
    projectPath,
    sourceBranch,
    targetBranch,
    title: DEFAULT_MR_TITLE,
  };

  const {
    data: {
      mergeRequestCreate: {
        mergeRequest: { iid: id },
        errors,
      },
    },
  } = await gqClient.mutate({
    mutation: createMergeRequestMutation,
    variables: { input },
  });

  return { id, errors };
};

/**
 * Creates a new security policy on the security policy project's policy file
 * @param {Object} payload contains the path to the project and the policy yaml value
 * @returns {Object} contains the branch containing the updated policy file and any errors
 */
const updatePolicy = async ({
  action = SECURITY_POLICY_ACTIONS.APPEND,
  name,
  namespacePath,
  yamlEditorValue,
}) => {
  const {
    data: {
      scanExecutionPolicyCommit: { branch, errors, validationErrors },
    },
  } = await gqClient.mutate({
    mutation: createScanExecutionPolicy,
    variables: {
      mode: action,
      name,
      fullPath: namespacePath,
      policyYaml: yamlEditorValue,
    },
  });

  return { branch, errors, validationErrors };
};

/**
 * Updates the assigned security policy project's policy file with the new policy yaml or creates one file if one does not exist
 * @param {Object} payload contains the currently assigned security policy project (if one exists), the path to the project, and the policy yaml value
 * @returns {Object} contains the currently assigned security policy project and the created merge request
 */
export const modifyPolicy = async ({
  action,
  assignedPolicyProject,
  name,
  namespacePath,
  yamlEditorValue,
}) => {
  const newPolicyCommitBranch = await updatePolicy({
    action,
    name,
    namespacePath,
    yamlEditorValue,
  });

  checkForErrors(newPolicyCommitBranch);

  const mergeRequest = await createMergeRequest({
    projectPath: assignedPolicyProject.fullPath,
    sourceBranch: newPolicyCommitBranch.branch,
    targetBranch: assignedPolicyProject.branch,
  });

  checkForErrors(mergeRequest);

  return mergeRequest;
};

/**
 * Creates a new security policy project and assigns it to the current project
 * @param {String} fullPath
 * @returns {Object} contains the new security policy project and any errors
 */
export const assignSecurityPolicyProject = async (fullPath) => {
  const {
    data: {
      securityPolicyProjectCreate: { project, errors },
    },
  } = await gqClient.mutate({
    mutation: createPolicyProject,
    variables: {
      fullPath,
    },
  });

  checkForErrors({ errors });

  return { ...project, branch: project?.branch?.rootRef, errors };
};

/**
 * Converts scanner strings to title case
 * @param {Array} scanners (e.g. 'container_scanning', `dast`, etcetera)
 * @returns {Array} (e.g. 'Container Scanning', `Dast`, etcetera)
 */
export const createHumanizedScanners = (scanners = []) =>
  scanners.map((scanner) => {
    return RULE_MODE_SCANNERS[scanner] || scanner;
  });

/**
 * Rule can not have both keys simultaneously
 * @param rule
 */
export const hasConflictingKeys = (rule) => {
  return BRANCH_TYPE_KEY in rule && BRANCHES_KEY in rule;
};

/**
 * Check if object has invalid keys in structure
 * @param object
 * @param allowedValues list of allowed values
 * @returns {boolean} true if object is invalid
 */
export const hasInvalidKey = (object, allowedValues) => {
  return !Object.keys(object).every((item) => allowedValues.includes(item));
};

/**
 * Checks for parameters unsupported by the policy "Rule Mode"
 * @param {Object} policy policy converted from YAML
 * @param {Array} primaryKeys list of primary policy keys
 * @param {Array} rulesKeys list of allowed keys for policy rule
 * @param {Array} actionsKeys list of allowed keys for policy rule
 * @returns {Boolean} whether the YAML is valid to be parsed into "Rule Mode"
 */
export const isValidPolicy = ({
  policy = {},
  primaryKeys = PRIMARY_POLICY_KEYS,
  rulesKeys = [],
  actionsKeys = [],
}) => {
  return !(
    hasInvalidKey(policy, primaryKeys) ||
    policy.rules?.some((rule) => hasInvalidKey(rule, rulesKeys)) ||
    policy.rules?.some(hasConflictingKeys) ||
    policy.actions?.some((action) => hasInvalidKey(action, actionsKeys))
  );
};

/**
 * Replaces whitespace and non-sluggish characters with a given separator
 * @param {String} str - The string to slugify
 * @param {String=} separator - The separator used to separate words (defaults to "-")
 * @returns {String}
 */
export const slugify = (str, separator = '-') => {
  const slug = str
    .trim()
    .replace(/[^a-zA-Z0-9_.*-/]+/g, separator)
    // Remove any duplicate separators or separator prefixes/suffixes
    .split(separator)
    .filter(Boolean)
    .join(separator);

  return slug === separator ? '' : slug;
};

/**
 * Replaces whitespace and non-sluggish characters with a given separator and returns array of values
 * @param {String} branches - comma-separated branches
 * @param {String=} separator - The separator used to separate words (defaults to "-")
 * @returns {String[]}
 */
export const slugifyToArray = (branches, separator = '-') =>
  branches
    .split(',')
    .map((branch) => slugify(branch, separator))
    .filter(Boolean);

/**
 * Validate cadence cron string if it exists in rule
 * @param policy
 * @returns {Boolean}
 */
export const hasInvalidCron = (policy) => {
  const hasInvalidCronString = (cronString) => (cronString ? !isValidCron(cronString) : false);

  return (policy.rules || []).some((rule) => hasInvalidCronString(rule?.cadence));
};

export const enforceIntValue = (value) => parseInt(value || '0', 10);

const NO_ITEM_SELECTED = 0;
const ONE_ITEM_SELECTED = 1;

/**
 *
 * @param selected items
 * @param items items used to render list
 * @param itemTypeName
 * @returns {*}
 */
export const renderMultiSelectText = (selected, items, itemTypeName) => {
  const itemsKeys = Object.keys(items);

  const defaultPlaceholder = sprintf(
    SELECTED_ITEMS_LABEL,
    {
      itemTypeName,
    },
    false,
  );

  /**
   * Another edge case
   * number of selected items and items are equal
   * but none of them match
   * without this check it would fall through to
   * ALL_SELECTED_LABEL
   * @type {string[]}
   */
  const commonItems = intersection(itemsKeys, selected);
  /**
   * Edge case for loading states when initial items are empty
   */
  if (itemsKeys.length === 0 || commonItems.length === 0) {
    return defaultPlaceholder;
  }

  switch (commonItems.length) {
    case itemsKeys.length:
      return sprintf(ALL_SELECTED_LABEL, { itemTypeName }, false);
    case NO_ITEM_SELECTED:
      return defaultPlaceholder;
    case ONE_ITEM_SELECTED:
      return items[commonItems[0]] || defaultPlaceholder;
    default:
      return sprintf(MULTIPLE_SELECTED_LABEL, {
        firstLabel: items[commonItems[0]],
        numberOfAdditionalLabels: commonItems.length - 1,
      });
  }
};

/**
 * Create project object based on provided properties
 * @param fullPath
 * @param id
 * @returns {{}}
 */
export const createProjectWithMinimumValues = ({ fullPath, id }) => ({
  ...(fullPath && { fullPath }),
  ...(id && { id: convertToGraphQLId(TYPENAME_PROJECT, id) }),
});

/**
 * Parse configuration file path and create state of UI component
 * @param configuration
 * @returns {{project: {}, showLinkedFile: boolean}}
 */
export const parseCustomFileConfiguration = (configuration = {}) => {
  const projectPath = configuration?.project;
  const projectId = configuration?.id;
  const hasFilePath = Boolean(configuration?.file);
  const hasRef = Boolean(configuration?.ref);
  const hasProjectPath = Boolean(projectPath);
  const hasProjectId = Boolean(projectId);
  const project =
    hasProjectPath || hasProjectId
      ? createProjectWithMinimumValues({ fullPath: projectPath, id: projectId })
      : null;

  return {
    showLinkedFile: hasFilePath || hasRef || hasProjectPath || hasProjectId,
    project,
  };
};
