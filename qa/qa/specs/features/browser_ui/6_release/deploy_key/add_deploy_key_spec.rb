# frozen_string_literal: true

module QA
  RSpec.describe 'Release' do
    describe 'Deploy key creation' do
      it 'user adds a deploy key', status_issue: 'https://gitlab.com/gitlab-org/quality/testcases/-/issues/390' do
        Flow::Login.sign_in

        key = Runtime::Key::RSA.new
        deploy_key_title = 'deploy key title'
        deploy_key_value = key.public_key

        deploy_key = Resource::DeployKey.fabricate! do |resource|
          resource.title = deploy_key_title
          resource.key = deploy_key_value
        end

        expect(deploy_key.md5_fingerprint).to eq key.md5_fingerprint

        Page::Project::Settings::Repository.perform do |setting|
          setting.expand_deploy_keys do |keys|
            expect(keys).to have_key(deploy_key_title, key.md5_fingerprint)
          end
        end
      end
    end
  end
end
