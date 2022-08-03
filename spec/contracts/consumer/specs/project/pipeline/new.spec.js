/* eslint-disable @gitlab/require-i18n-strings */

import { pactWith } from 'jest-pact';

import { NewProjectPipeline } from '../../../fixtures/project/pipeline/create_a_new_pipeline.fixture';
import { postProjectPipelines } from '../../../resources/api/project/pipelines';

const CONSUMER_NAME = 'Pipelines#new';
const CONSUMER_LOG = '../logs/consumer.log';
const CONTRACT_DIR = '../contracts/project/pipeline/new';
const PROVIDER_NAME = 'POST Create a new pipeline';

// API endpoint: /pipelines.json
pactWith(
  {
    consumer: CONSUMER_NAME,
    provider: PROVIDER_NAME,
    log: CONSUMER_LOG,
    dir: CONTRACT_DIR,
  },

  (provider) => {
    describe(PROVIDER_NAME, () => {
      beforeEach(async () => {
        const interaction = {
          ...NewProjectPipeline.scenario,
          ...NewProjectPipeline.request,
          willRespondWith: NewProjectPipeline.success,
        };

        provider.addInteraction(interaction);
      });

      it('returns a successful body', async () => {
        const newPipeline = await postProjectPipelines({
          url: provider.mockService.baseUrl,
        });

        expect(newPipeline.status).toEqual(NewProjectPipeline.success.status);
      });
    });
  },
);

/* eslint-enable @gitlab/require-i18n-strings */
