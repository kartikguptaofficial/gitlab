# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::DesignManagement::Designs::ResizedImageController, feature_category: :design_management do
  include DesignManagementTestHelpers

  let_it_be(:project) { create(:project, :private) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:viewer) { issue.author }
  let_it_be(:size) { :v432x230 }

  let(:design) { create(:design, :with_smaller_image_versions, issue: issue, versions_count: 2) }
  let(:design_id) { design.id }
  let(:sha) { design.versions.first.sha }

  before do
    enable_design_management
  end

  describe 'GET #show' do
    subject(:response) do
      get(:show,
        params: {
          namespace_id: project.namespace,
          project_id: project,
          design_id: design_id,
          sha: sha,
          id: size
        }
      )
    end

    before do
      sign_in(viewer)
    end

    context 'when the user does not have permission' do
      let_it_be(:viewer) { create(:user) }

      specify do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    describe 'Response headers' do
      it 'completes the request successfully' do
        expect(response).to have_gitlab_http_status(:ok)
      end

      it 'sets Content-Disposition as attachment' do
        filename = design.filename

        expect(response.header['Content-Disposition']).to eq(%(attachment; filename=\"#{filename}\"; filename*=UTF-8''#{filename}))
      end

      it 'serves files with Workhorse' do
        expect(response.header[Gitlab::Workhorse::DETECT_HEADER]).to eq 'true'
      end

      it 'sets appropriate caching headers' do
        expect(response.header['Cache-Control']).to eq('private')
        expect(response.header['ETag']).to be_present
      end
    end

    context 'when design does not exist' do
      let(:design_id) { 'foo' }

      specify do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when size is invalid' do
      let_it_be(:size) { :foo }

      it 'returns a 404' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    describe 'sha param' do
      let(:newest_version) { design.versions.ordered.first }
      let(:oldest_version) { design.versions.ordered.last }

      # The design images generated by Factorybot are identical, so
      # refer to the `ETag` header, which is uniquely generated from the Action
      # (the record that represents the design at a specific version), to
      # verify that the correct file is being returned.
      def etag(action)
        ActionDispatch::TestResponse.new.send(:generate_weak_etag, [action.cache_key])
      end

      specify { expect(newest_version.sha).not_to eq(oldest_version.sha) }

      context 'when sha is the newest version sha' do
        let(:sha) { newest_version.sha }

        it 'serves the newest image' do
          action = newest_version.actions.first

          expect(response.header['ETag']).to eq(etag(action))
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when sha is the oldest version sha' do
        let(:sha) { oldest_version.sha }

        it 'serves the oldest image' do
          action = oldest_version.actions.first

          expect(response.header['ETag']).to eq(etag(action))
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when sha is nil' do
        let(:sha) { nil }

        it 'serves the newest image' do
          action = newest_version.actions.first

          expect(response.header['ETag']).to eq(etag(action))
          expect(response).to have_gitlab_http_status(:ok)
        end
      end

      context 'when sha is not a valid version sha' do
        let(:sha) { '570e7b2abdd848b95f2f578043fc23bd6f6fd24d' }

        it 'returns a 404' do
          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when multiple design versions have the same sha hash' do
        let(:sha) { newest_version.sha }

        before do
          create(
            :design,
            :with_smaller_image_versions,
            issue: create(:issue, project: project),
            versions_count: 1,
            versions_sha: sha
          )
        end

        it 'serves the newest image' do
          action = newest_version.actions.first

          expect(response.header['ETag']).to eq(etag(action))
          expect(response).to have_gitlab_http_status(:ok)
        end
      end
    end

    context 'when design does not have a smaller image size available' do
      let(:design) { create(:design, :with_file, issue: issue) }

      it 'returns a 404' do
        expect(response).to have_gitlab_http_status(:not_found)
      end
    end
  end
end
