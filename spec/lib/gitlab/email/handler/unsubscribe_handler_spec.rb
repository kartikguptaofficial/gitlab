require 'spec_helper'
require_relative '../email_shared_blocks'

describe Gitlab::Email::Handler::UnsubscribeHandler do
  include_context :email_shared_context

  before do
    stub_incoming_email_setting(enabled: true, address: 'reply+%{key}@appmail.adventuretime.ooo')
    stub_config_setting(host: 'localhost')
  end

  let(:email_raw) { fixture_file('emails/valid_reply.eml').gsub(mail_key, "#{mail_key}+unsubscribe") }
  let(:project) { create(:empty_project, :public) }
  let(:user) { create(:user) }
  let(:noteable) { create(:issue, project: project) }

  let!(:sent_notification) { SentNotification.record(noteable, user.id, mail_key) }

  context 'when notification concerns a commit' do
    let(:commit) { create(:commit, project: project) }
    let!(:sent_notification) { SentNotification.record(commit, user.id, mail_key) }

    it 'handler does not raise an error' do
      expect { receiver.execute }.not_to raise_error
    end
  end

  context 'user is unsubscribed' do
    it 'leaves user unsubscribed' do
      expect { receiver.execute }.not_to change { noteable.subscribed?(user) }.from(false)
    end
  end

  context 'user is subscribed' do
    before do
      noteable.subscribe(user)
    end

    it 'unsubscribes user from notable' do
      expect { receiver.execute }.to change { noteable.subscribed?(user) }.from(true).to(false)
    end
  end

  context 'when the noteable could not be found' do
    before do
      noteable.destroy
    end

    it 'raises a NoteableNotFoundError' do
      expect { receiver.execute }.to raise_error(Gitlab::Email::NoteableNotFoundError)
    end
  end

  context 'when no sent notification for the mail key could be found' do
    let(:email_raw) { fixture_file('emails/wrong_mail_key.eml') }

    it 'raises a SentNotificationNotFoundError' do
      expect { receiver.execute }.to raise_error(Gitlab::Email::SentNotificationNotFoundError)
    end
  end
end
