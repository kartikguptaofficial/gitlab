# frozen_string_literal: true

RSpec.shared_context 'with ai features enabled for group' do
  before do
    allow(Gitlab).to receive(:com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    allow(group.namespace_settings).to receive(:ai_settings_allowed?).and_return(true)
    group.namespace_settings.reload.update!(experiment_features_enabled: true)
  end
end

RSpec.shared_context 'with experiment features disabled for group' do
  before do
    allow(Gitlab).to receive(:com?).and_return(true)
    stub_ee_application_setting(should_check_namespace_plan: true)
    allow(group.namespace_settings).to receive(:ai_settings_allowed?).and_return(true)
    group.namespace_settings.update!(experiment_features_enabled: false)
  end
end
