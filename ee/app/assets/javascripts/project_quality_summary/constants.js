import { s__ } from '~/locale';

export const FEEDBACK_ISSUE_URL = 'https://gitlab.com/gitlab-org/gitlab/-/issues/342634';
export const BANNER_DISMISSED_COOKIE_KEY = 'project_quality_summary_feedback_banner_dismissed';

export const i18n = {
  testRuns: {
    title: s__('ProjectQualitySummary|Test runs'),
    popoverBody: s__(
      'ProjectQualitySummary|The percentage of tests that succeed, fail, or are skipped.',
    ),
    learnMoreLink: s__('ProjectQualitySummary|Learn more about test reports'),
    fullReportLink: s__('ProjectQualitySummary|See full report'),
    successLabel: s__('ProjectQualitySummary|Success'),
    failureLabel: s__('ProjectQualitySummary|Failure'),
    skippedLabel: s__('ProjectQualitySummary|Skipped'),
    emptyStateDescription: s__(
      'ProjectQualitySummary|Get insight into the overall percentage of tests in your project that succeed, fail and are skipped.',
    ),
    emptyStateLink: s__('ProjectQualitySummary|Set up test runs'),
    emptyStateLinkLabel: s__('ProjectQualitySummary|Set up test runs (opens in a new tab)'),
  },
  coverage: {
    title: s__('ProjectQualitySummary|Test coverage'),
    popoverBody: s__('ProjectQualitySummary|Measure of how much of your code is covered by tests.'),
    learnMoreLink: s__('ProjectQualitySummary|Learn more about test coverage'),
    fullReportLink: s__('ProjectQualitySummary|See project Code Coverage Statistics'),
    coverageLabel: s__('ProjectQualitySummary|Coverage'),
  },
  subHeader: s__('ProjectQualitySummary|Latest pipeline results'),
  fetchError: s__(
    'ProjectQualitySummary|An error occurred while trying to fetch project quality statistics',
  ),
  banner: {
    title: s__('ProjectQualitySummary|Help us improve this page'),
    text: s__(
      'ProjectQualitySummary|The project quality page helps you understand how code quality is trending for your project. Let us know how we can improve it!',
    ),
    button: s__('ProjectQualitySummary|Provide feedback'),
  },
};
