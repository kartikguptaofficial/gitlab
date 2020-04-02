# frozen_string_literal: true

require 'spec_helper'

describe EE::SystemHooksService do
  let(:group_member) { create(:group_member) }
  let(:user) { create(:user) }

  context 'when group member' do
    context 'event data' do
      it { expect(event_data(group_member, :create)).to include(:event_name, :created_at, :updated_at, :group_name, :group_path, :group_plan, :group_id, :user_name, :user_username, :user_email, :user_id, :group_access) }
      it { expect(event_data(group_member, :destroy)).to include(:event_name, :created_at, :updated_at, :group_name, :group_path, :group_plan, :group_id, :user_name, :user_username, :user_email, :user_id, :group_access) }
    end
  end

  context 'when user' do
    context 'event data' do
      context 'for GitLab.com' do
        before do
          expect(Gitlab).to receive(:com?).and_return(true)
        end

        it { expect(event_data(user, :create)).to include(:event_name, :name, :created_at, :updated_at, :email, :user_id, :username, :email_opted_in, :email_opted_in_ip, :email_opted_in_source, :email_opted_in_at) }
        it { expect(event_data(user, :destroy)).to include(:event_name, :name, :created_at, :updated_at, :email, :user_id, :username, :email_opted_in, :email_opted_in_ip, :email_opted_in_source, :email_opted_in_at) }
      end

      context 'for non-GitLab.com' do
        before do
          expect(Gitlab).to receive(:com?).and_return(false)
        end

        it { expect(event_data(user, :create)).to include(:event_name, :name, :created_at, :updated_at, :email, :user_id, :username) }
        it { expect(event_data(user, :destroy)).to include(:event_name, :name, :created_at, :updated_at, :email, :user_id, :username) }
      end
    end
  end

  def event_data(*args)
    SystemHooksService.new.send :build_event_data, *args
  end
end
