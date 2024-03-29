<script>
import { GlAvatar, GlIcon, GlIntersperse, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { compact } from 'lodash';
import { createAlert } from '~/alert';
import { __ } from '~/locale';

import { WORKSPACE_GROUP, WORKSPACE_PROJECT } from '~/issues/constants';
import usersAutocompleteQuery from '~/graphql_shared/queries/users_autocomplete.query.graphql';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { OPERATORS_TO_GROUP, OPTIONS_NONE_ANY } from '../constants';

import BaseToken from './base_token.vue';

export default {
  components: {
    BaseToken,
    GlAvatar,
    GlIcon,
    GlIntersperse,
    GlFilteredSearchSuggestion,
  },
  mixins: [glFeatureFlagMixin()],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      // current users visible in list
      users: this.config.initialUsers || [],
      allUsers: this.config.initialUsers || [],
      loading: false,
      selectedUsernames: [],
    };
  },
  computed: {
    defaultUsers() {
      return this.config.defaultUsers || OPTIONS_NONE_ANY;
    },
    preloadedUsers() {
      return this.config.preloadedUsers || [];
    },
    namespace() {
      return this.config.isProject ? WORKSPACE_PROJECT : WORKSPACE_GROUP;
    },
    fetchUsersQuery() {
      return this.config.fetchUsers ? this.config.fetchUsers : this.fetchUsersBySearchTerm;
    },
    multiSelectEnabled() {
      return (
        this.config.multiSelect &&
        this.glFeatures.groupMultiSelectTokens &&
        OPERATORS_TO_GROUP.includes(this.value.operator)
      );
    },
  },
  watch: {
    value: {
      deep: true,
      immediate: true,
      handler(newValue) {
        const { data } = newValue;

        if (!this.multiSelectEnabled) {
          return;
        }

        // don't add empty values to selectedUsernames
        if (!data) {
          return;
        }

        if (Array.isArray(data)) {
          this.selectedUsernames = data;
          // !active so we don't add strings while searching, e.g. r, ro, roo
          // !includes so we don't add the same usernames (if @input is emitted twice)
        } else if (!this.active && !this.selectedUsernames.includes(data)) {
          this.selectedUsernames = this.selectedUsernames.concat(data);
        }
      },
    },
  },
  methods: {
    getActiveUser(users, data) {
      return users.find((user) => user.username.toLowerCase() === data.toLowerCase());
    },
    getAvatarUrl(user) {
      return user?.avatarUrl || user?.avatar_url;
    },
    displayNameFor(username) {
      return this.getActiveUser(this.allUsers, username)?.name || username;
    },
    avatarFor(username) {
      const user = this.getActiveUser(this.allUsers, username);
      return this.getAvatarUrl(user);
    },
    addCheckIcon(username) {
      return this.multiSelectEnabled && this.selectedUsernames.includes(username);
    },
    addPadding(username) {
      return this.multiSelectEnabled && !this.selectedUsernames.includes(username);
    },
    handleSelected(username) {
      if (!this.multiSelectEnabled) {
        return;
      }

      const index = this.selectedUsernames.indexOf(username);
      if (index > -1) {
        this.selectedUsernames.splice(index, 1);
      } else {
        this.selectedUsernames.push(username);
      }

      this.$emit('input', { ...this.value, data: '' });
    },
    fetchUsersBySearchTerm(search) {
      return this.$apollo
        .query({
          query: usersAutocompleteQuery,
          variables: { fullPath: this.config.fullPath, search, isProject: this.config.isProject },
        })
        .then(({ data }) => data[this.namespace]?.autocompleteUsers);
    },
    fetchUsers(searchTerm) {
      this.loading = true;
      const fetchPromise = this.config.fetchPath
        ? this.config.fetchUsers(this.config.fetchPath, searchTerm)
        : this.fetchUsersQuery(searchTerm);

      fetchPromise
        .then((res) => {
          // We'd want to avoid doing this check but
          // users.json and /groups/:id/members & /projects/:id/users
          // return response differently

          // TODO: rm when completed https://gitlab.com/gitlab-org/gitlab/-/issues/345756
          this.users = Array.isArray(res) ? compact(res) : compact(res.data);
          this.allUsers = this.allUsers.concat(this.users);
        })
        .catch(() =>
          createAlert({
            message: __('There was a problem fetching users.'),
          }),
        )
        .finally(() => {
          this.loading = false;
        });
    },
  },
};
</script>

<template>
  <base-token
    :config="config"
    :value="value"
    :active="active"
    :suggestions-loading="loading"
    :suggestions="users"
    :get-active-token-value="getActiveUser"
    :default-suggestions="defaultUsers"
    :preloaded-suggestions="preloadedUsers"
    :multi-select-values="selectedUsernames"
    v-bind="$attrs"
    @fetch-suggestions="fetchUsers"
    @token-selected="handleSelected"
    v-on="$listeners"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      <gl-intersperse v-if="multiSelectEnabled" separator=",">
        <span
          v-for="(username, index) in selectedUsernames"
          :key="username"
          :class="{ 'gl-ml-2': index > 0 }"
          ><gl-avatar :size="16" :src="avatarFor(username)" class="gl-mr-1" />{{
            displayNameFor(username)
          }}</span
        >
      </gl-intersperse>
      <template v-else>
        <gl-avatar
          v-if="activeTokenValue"
          :size="16"
          :src="getAvatarUrl(activeTokenValue)"
          class="gl-mr-2"
        />
        {{ activeTokenValue ? activeTokenValue.name : inputValue }}
      </template>
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="user in suggestions"
        :key="user.username"
        :value="user.username"
      >
        <div
          class="gl-display-flex gl-align-items-center"
          :class="{ 'gl-pl-6': addPadding(user.username) }"
        >
          <gl-icon
            v-if="addCheckIcon(user.username)"
            name="check"
            class="gl-mr-3 gl-text-secondary gl-flex-shrink-0"
          />
          <gl-avatar :size="32" :src="getAvatarUrl(user)" />
          <div>
            <div>{{ user.name }}</div>
            <div>@{{ user.username }}</div>
          </div>
        </div>
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
