import { s__, sprintf } from '~/locale';

export const i18n = {
  GITLAB_DUO: s__('AI|GitLab Duo'),
  GENIE_TOOLTIP: s__('AI|What does the selected code mean?'),
  GENIE_NO_CONTAINER_ERROR: s__("AI|The container element wasn't found, stopping AI Genie."),
  GENIE_CHAT_TITLE: s__('AI|Code Explanation'),
  GENIE_CHAT_CLOSE_LABEL: s__('AI|Close the Code Explanation'),
  GENIE_CHAT_LEGAL_NOTICE: sprintf(
    s__(
      'AI|You are not allowed to copy any part of this output into issues, comments, GitLab source code, commit messages, merge requests or any other user interface in the %{gitlabOrg} or %{gitlabCom} groups.',
    ),
    { gitlabOrg: '<code>/gitlab-org</code>', gitlabCom: '<code>/gitlab-com</code>' },
    false,
  ),
  GENIE_CHAT_LEGAL_GENERATED_BY_AI: s__('AI|Responses generated by AI'),
  REQUEST_ERROR: s__('AI|Something went wrong. Please try again later'),
  EXPERIMENT_BADGE: s__('AI|Experiment'),
  EXPERIMENT_POPOVER_TITLE: s__("AI|What's an Experiment?"),
  EXPERIMENT_POPOVER_CONTENT: s__(
    "AI|An %{linkStart}Experiment%{linkEnd} is a feature that's in the process of being developed. It's not production-ready. We encourage users to try Experimental features and provide feedback. An Experiment: %{bullets}",
  ),
  EXPERIMENT_POPOVER_BULLETS: [
    s__('AI|May be unstable'),
    s__('AI|Has no support and might not be documented'),
    s__('AI|Can be removed at any time'),
  ],
  EXPLAIN_CODE_PROMPT: s__(
    'AI|Explain the code from %{filePath} in human understandable language presented in Markdown format. In the response add neither original code snippet nor any title. `%{text}`. If it is not programming code, say `The selected text is not code. I am afraid this feature is for explaining code only. Would you like to ask a different question about the selected text?` and wait for another question.',
  ),
  TOO_LONG_ERROR_MESSAGE: s__(
    'AI|There is too much text in the chat. Please try again with a shorter text.',
  ),
  GENIE_CHAT_PROMPT_PLACEHOLDER: s__('AI|GitLab Duo Chat'),
  GENIE_CHAT_EMPTY_STATE_TITLE: s__('AI|Ask a question'),
  GENIE_CHAT_EMPTY_STATE_DESC: s__('AI|AI generated explanations will appear here.'),
  GENIE_CHAT_LEGAL_DISCLAIMER: s__(
    "AI|May provide inappropriate responses not representative of GitLab's views. Do not input personal data.",
  ),
  GENIE_CHAT_NEW_CHAT: s__('AI|New chat'),
  GENIE_CHAT_LOADING_MESSAGE: s__('AI|%{tool} is %{transition} an answer'),
  GENIE_CHAT_LOADING_TRANSITIONS: [
    s__('AI|finding'),
    s__('AI|working on'),
    s__('AI|generating'),
    s__('AI|producing'),
  ],
  GENIE_CHAT_FEEDBACK_LINK: s__('AI|Give feedback to improve this answer.'),
  GENIE_CHAT_FEEDBACK_THANKS: s__('AI|Thank you for your feedback.'),
};
export const GENIE_CHAT_LOADING_TRANSITION_DURATION = 7500;
export const TOO_LONG_ERROR_TYPE = 'too-long';
export const AI_GENIE_DEBOUNCE = 300;
export const GENIE_CHAT_MODEL_ROLES = {
  user: 'user',
  system: 'system',
  assistant: 'assistant',
};

export const CHAT_MESSAGE_TYPES = {
  tool: 'tool',
};

export const FEEDBACK_OPTIONS = [
  {
    title: s__('AI|Helpful'),
    icon: 'thumb-up',
    value: 'helpful',
  },
  {
    title: s__('AI|Unhelpful'),
    icon: 'thumb-down',
    value: 'unhelpful',
  },
  {
    title: s__('AI|Wrong'),
    icon: 'status_warning',
    value: 'wrong',
  },
];

export const EXPLAIN_CODE_TRACKING_EVENT_NAME = 'explain_code_blob_viewer';
export const TANUKI_BOT_TRACKING_EVENT_NAME = 'ask_gitlab_chat';
export const GENIE_CHAT_RESET_MESSAGE = '/reset';
export const GENIE_CHAT_CLEAN_MESSAGE = '/clean';

export const DOCUMENTATION_SOURCE_TYPES = {
  HANDBOOK: {
    value: 'handbook',
    icon: 'book',
  },
  DOC: {
    value: 'doc',
    icon: 'documents',
  },
  BLOG: {
    value: 'blog',
    icon: 'list-bulleted',
  },
};
