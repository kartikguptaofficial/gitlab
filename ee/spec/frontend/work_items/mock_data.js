export const groupOrProjectWorkItemTypesQueryResponse = {
  data: {
    workspace: {
      id: 'gid://gitlab/WorkItem/1',
      workItemTypes: {
        nodes: [
          { id: 'gid://gitlab/WorkItems::Type/1', name: 'Issue' },
          { id: 'gid://gitlab/WorkItems::Type/2', name: 'Incident' },
          { id: 'gid://gitlab/WorkItems::Type/3', name: 'Task' },
        ],
      },
    },
  },
};

export const createWorkItemMutationResponse = {
  data: {
    workItemCreate: {
      __typename: 'WorkItemCreatePayload',
      workItem: {
        __typename: 'WorkItem',
        id: 'gid://gitlab/WorkItem/1',
        iid: '1',
        title: 'Updated title',
        state: 'OPEN',
        description: 'description',
        confidential: false,
        createdAt: '2022-08-03T12:41:54Z',
        closedAt: null,
        webUrl: 'http://127.0.0.1:3000/groups/gitlab-org/-/work_items/1',
        project: {
          __typename: 'Project',
          id: '1',
          fullPath: 'test-project-path',
          archived: false,
        },
        workItemType: {
          __typename: 'WorkItemType',
          id: 'gid://gitlab/WorkItems::Type/5',
          name: 'Task',
          iconName: 'issue-type-task',
        },
        userPermissions: {
          deleteWorkItem: false,
          updateWorkItem: false,
        },
        widgets: [],
      },
      errors: [],
    },
  },
};

export const createWorkItemMutationErrorResponse = {
  data: {
    workItemCreate: {
      __typename: 'WorkItemCreatePayload',
      workItem: null,
      errors: ['Title is too long (maximum is 255 characters)'],
    },
  },
};
