# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sidebars::UserSettings::Panel, feature_category: :navigation do
  let_it_be(:user) { create(:user) }

  let(:context) { Sidebars::Context.new(current_user: user, container: nil) }

  subject { described_class.new(context) }

  it_behaves_like 'a panel with uniquely identifiable menu items'
  it_behaves_like 'a panel without placeholders'
end
