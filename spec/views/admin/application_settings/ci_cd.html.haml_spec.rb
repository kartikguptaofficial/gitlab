# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/ci_cd.html.haml' do
  let_it_be(:app_settings) { build(:application_setting) }
  let_it_be(:user) { create(:admin) }

  let_it_be(:default_plan_limits) { create(:plan_limits, :default_plan, :with_package_file_sizes) }

  before do
    assign(:application_setting, app_settings)
    assign(:plans, [default_plan_limits.plan])
    allow(view).to receive(:current_user).and_return(user)
  end

  describe 'CI CD Runners' do
    it 'has the setting section' do
      render

      expect(rendered).to have_css("#js-runner-settings")
    end

    it 'renders the correct setting section content' do
      render

      expect(rendered).to have_content("Runner registration")
      expect(rendered).to have_content(s_("Runners|If both settings are disabled, new runners cannot be registered."))
      expect(rendered).to have_content(
        s_("Runners|Fetch GitLab Runner release version data from GitLab.com")
      )
    end
  end
end
