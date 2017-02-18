/* eslint-disable no-new */
/**
 * Renders a deploy board.
 *
 * A deploy board is composed by:
 * - Information area with percentage of completion.
 * - Instances with status.
 * - Button Actions.
 * [Mockup](https://gitlab.com/gitlab-org/gitlab-ce/uploads/2f655655c0eadf655d0ae7467b53002a/environments__deploy-graphic.png)
 *
 * The data of each deploy board needs to be fetched when we render the component.
 *
 * The endpoint response can sometimes be 204, in those cases we need to retry the request.
 * This should be done using backoff pooling and we should make no more than 3 request
 * for each deploy board.
 * After the third request we need to show a message saying we can't fetch the data.
 * Please refer to this [comment](https://gitlab.com/gitlab-org/gitlab-ee/issues/1589#note_23630610)
 * for more information
 */

const Vue = require('vue');
const instanceComponent = require('./deploy_board_instance_component');
require('../../lib/utils/common_utils');
const Flash = require('../../flash');

module.exports = Vue.component('deploy_boards_components', {

  components: {
    instanceComponent,
  },

  props: {
    store: {
      type: Object,
      required: true,
    },

    service: {
      type: Object,
      required: true,
    },

    deployBoardData: {
      type: Object,
      required: true,
    },

    environmentID: {
      type: Number,
      required: true,
    },
  },

  data() {
    return {
      isLoading: false,
      hasError: false,
      backOffRequestCounter: 0,
    };
  },

  created() {
    this.isLoading = true;

    gl.utils.backOff((next, stop) => {
      this.service.getDeployBoard(this.environmentID)
        .then((resp) => {
          if (resp.status === 204) {
            this.backOffRequestCounter = this.backOffRequestCounter += 1;

            if (this.backOffRequestCounter < 3) {
              next();
            }
          }
          stop(resp);
          return resp;
        })
        .then(resp => resp.json())
        .then((response) => {
          if (!Object.keys(response).length && this.backOffRequestCounter === 3) {
            this.hasError = true;
          }

          this.store.storeDeployBoard(this.environmentID, response);
          return response;
        })
        .then((response) => {
          if ((!Object.keys(response).length &&
            this.backOffRequestCounter === 3) ||
            Object.keys(response).length) {
            this.isLoading = false;
          }
        })
        .catch((error) => {
          stop(error);
          this.isLoading = false;
          this.hasError = true;
        });
    })
    .catch(() => {
      new Flash('An error occurred while fetching the deploy board.', 'alert');
    });
  },

  template: `
    <div class="js-deploy-board deploy-board">

      <div v-if="isLoading">
        <i class="fa fa-spinner fa-spin"></i>
      </div>

      <div v-if="!isLoading && !hasError">
        <section class="deploy-board-information">
          <span class="percentage">{{deployBoardData.completion}}%</span>
          <span class="text">Complete</span>
        </section>

        <section class="deploy-board-instances">
          <p class="text">Instances</p>

          <div class="deploy-board-instances-container">
            <template v-for="instance in deployBoardData.instances">
              <instance-component
                :status="instance.status"
                :tooltipText="instance.tooltip">
              </instance-component>
            </template>
          </div>
        </section>

        <section class="deploy-board-actions">
          <a class="btn"
            data-method="post"
            rel="nofollow"
            v-if="deployBoardData.rollback_url"
            :href="deployBoardData.rollback_url">
            Rollback
          </a>

          <a class="btn btn-red btn-inverted"
            data-method="post"
            rel="nofollow"
            v-if="deployBoardData.abort_url"
            :href="deployBoardData.abort_url">
            Abort
          </a>
        </section>
      </div>

      <div v-if="!isLoading && hasError">
        We can't fetch the data right now. Please try again later.
      </div>
    </div>
  `,
});
