# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Profiles::TwoFactorAuthsController, feature_category: :authentication_and_authorization do
  before do
    # `user` should be defined within the action-specific describe blocks
    sign_in(user)

    allow(subject).to receive(:current_user).and_return(user)
  end

  shared_examples 'user must first verify their primary email address' do
    before do
      allow(user).to receive(:primary_email_verified?).and_return(false)
    end

    it 'redirects to profile_emails_path' do
      go

      expect(response).to redirect_to(profile_emails_path)
    end

    it 'displays a notice' do
      go

      expect(flash[:notice])
        .to eq _('You need to verify your primary email first before enabling Two-Factor Authentication.')
    end
  end

  shared_examples 'user must enter a valid current password' do
    let(:current_password) { '123' }
    let(:error_message) { { message: _('You must provide a valid current password.') } }

    it 'requires the current password', :aggregate_failures do
      go

      expect(assigns[:error]).to eq(error_message)
      expect(response).to render_template(:show)
    end

    it 'assigns qr_code' do
      code = double('qr code')
      expect(subject).to receive(:build_qr_code).and_return(code)

      go
      expect(assigns[:qr_code]).to eq(code)
    end

    it 'assigns account_string' do
      go
      expect(assigns[:account_string]).to eq("#{Gitlab.config.gitlab.host}:#{user.email}")
    end

    context 'when the user is on the last sign in attempt' do
      it do
        user.update!(failed_attempts: User.maximum_attempts.pred)

        go

        expect(user.reload).to be_access_locked
      end
    end

    context 'when user authenticates with an external service' do
      before do
        allow(user).to receive(:password_automatically_set?).and_return(true)
      end

      it 'does not require the current password', :aggregate_failures do
        go

        expect(assigns[:error]).not_to eq(error_message)
      end
    end

    context 'when password authentication is disabled' do
      before do
        stub_application_setting(password_authentication_enabled_for_web: false)
      end

      it 'does not require the current password', :aggregate_failures do
        go

        expect(assigns[:error]).not_to eq(error_message)
      end
    end

    context 'when the user is an LDAP user' do
      before do
        allow(user).to receive(:ldap_user?).and_return(true)
      end

      it 'does not require the current password', :aggregate_failures do
        go

        expect(assigns[:error]).not_to eq(error_message)
      end
    end
  end

  describe 'GET show' do
    let_it_be_with_reload(:user) { create(:user) }

    it 'generates otp_secret for user' do
      expect(User).to receive(:generate_otp_secret).with(32).and_call_original.once

      get :show
    end

    it 'assigns qr_code' do
      code = double('qr code')
      expect(subject).to receive(:build_qr_code).and_return(code)

      get :show
      expect(assigns[:qr_code]).to eq(code)
    end

    it 'generates a single otp_secret with multiple page loads', :freeze_time do
      expect(User).to receive(:generate_otp_secret).with(32).and_call_original.once

      user.update!(otp_secret: nil, otp_secret_expires_at: nil)

      2.times do
        get :show
      end
    end

    it 'generates a new otp_secret once the ttl has expired' do
      expect(User).to receive(:generate_otp_secret).with(32).and_call_original.once

      user.update!(otp_secret: "FT7KAVNU63YZH7PBRVPVL7CPSAENXY25", otp_secret_expires_at: 2.minutes.from_now)

      travel_to(10.minutes.from_now) do
        get :show
      end
    end

    it_behaves_like 'user must first verify their primary email address' do
      let(:go) { get :show }
    end
  end

  describe 'POST create' do
    let_it_be_with_reload(:user) { create(:user) }

    let(:pin) { 'pin-code' }
    let(:current_password) { user.password }

    def go
      post :create, params: { pin_code: pin, current_password: current_password }
    end

    context 'with valid pin' do
      before do
        allow(user).to receive(:validate_and_consume_otp!).with(pin).and_return(true)
      end

      it 'enables 2fa for the user' do
        go

        user.reload
        expect(user).to be_two_factor_enabled
      end

      it 'presents plaintext codes for the user to save' do
        expect(user).to receive(:generate_otp_backup_codes!).and_return(%w(a b c))

        go

        expect(assigns[:codes]).to match_array %w(a b c)
      end

      it 'calls to delete other sessions' do
        expect(ActiveSession).to receive(:destroy_all_but_current)

        go
      end

      it 'dismisses the `TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK` callout' do
        expect(controller.helpers).to receive(:dismiss_two_factor_auth_recovery_settings_check)

        go
      end

      it 'renders create' do
        go
        expect(response).to render_template(:create)
        expect(user.otp_backup_codes?).to be_eql(true)
      end

      it 'do not create new backup codes if exists' do
        expect(user).to receive(:otp_backup_codes?).and_return(true)
        go
        expect(response).to redirect_to(profile_two_factor_auth_path)
      end

      it 'calls to delete other sessions when backup codes already exist' do
        expect(user).to receive(:otp_backup_codes?).and_return(true)
        expect(ActiveSession).to receive(:destroy_all_but_current)
        go
      end

      context 'when webauthn_without_totp flag is disabled' do
        before do
          stub_feature_flags(webauthn_without_totp: false)
          expect(user).to receive(:validate_and_consume_otp!).with(pin).and_return(true)
        end

        it 'enables 2fa for the user' do
          go

          user.reload
          expect(user).to be_two_factor_enabled
        end

        it 'presents plaintext codes for the user to save' do
          expect(user).to receive(:generate_otp_backup_codes!).and_return(%w(a b c))

          go

          expect(assigns[:codes]).to match_array %w(a b c)
        end

        it 'calls to delete other sessions' do
          expect(ActiveSession).to receive(:destroy_all_but_current)

          go
        end

        it 'dismisses the `TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK` callout' do
          expect(controller.helpers).to receive(:dismiss_two_factor_auth_recovery_settings_check)

          go
        end

        it 'renders create' do
          go
          expect(response).to render_template(:create)
        end

        it 'renders create even if backup code already exists' do
          expect(user).to receive(:otp_backup_codes?).and_return(true)
          go
          expect(response).to render_template(:create)
        end
      end
    end

    context 'with invalid pin' do
      before do
        expect(user).to receive(:validate_and_consume_otp!).with(pin).and_return(false)
      end

      it 'assigns error' do
        go
        expect(assigns[:error]).to eq({ message: 'Invalid pin code.' })
      end

      it 'assigns qr_code' do
        code = double('qr code')
        expect(subject).to receive(:build_qr_code).and_return(code)

        go
        expect(assigns[:qr_code]).to eq(code)
      end

      it 'assigns account_string' do
        go
        expect(assigns[:account_string]).to eq("#{Gitlab.config.gitlab.host}:#{user.email}")
      end

      it 'renders show' do
        go
        expect(response).to render_template(:show)
      end
    end

    it_behaves_like 'user must enter a valid current password'

    it_behaves_like 'user must first verify their primary email address'
  end

  describe 'POST codes' do
    let_it_be_with_reload(:user) { create(:user, :two_factor) }

    let(:current_password) { user.password }

    it 'presents plaintext codes for the user to save' do
      expect(user).to receive(:generate_otp_backup_codes!).and_return(%w(a b c))

      post :codes, params: { current_password: current_password }
      expect(assigns[:codes]).to match_array %w(a b c)
    end

    it 'persists the generated codes' do
      post :codes, params: { current_password: current_password }

      user.reload
      expect(user.otp_backup_codes).not_to be_empty
    end

    it 'dismisses the `TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK` callout' do
      expect(controller.helpers).to receive(:dismiss_two_factor_auth_recovery_settings_check)

      post :codes, params: { current_password: current_password }
    end

    it_behaves_like 'user must enter a valid current password' do
      let(:go) { post :codes, params: { current_password: current_password } }
    end
  end

  describe 'POST create_webauthn' do
    let_it_be_with_reload(:user) { create(:user) }
    let(:client) { WebAuthn::FakeClient.new('http://localhost', encoding: :base64) }
    let(:credential) { create_credential(client: client, rp_id: request.host) }

    let(:params) { { device_registration: { name: 'touch id', device_response: device_response } } } # rubocop:disable Rails/SaveBang

    let(:params_with_password) { { device_registration: { name: 'touch id', device_response: device_response }, current_password: user.password } } # rubocop:disable Rails/SaveBang

    before do
      session[:challenge] = challenge
    end

    def go
      post :create_webauthn, params: params
    end

    def challenge
      @_challenge ||= begin
        options_for_create = WebAuthn::Credential.options_for_create(
          user: { id: user.webauthn_xid, name: user.username },
          authenticator_selection: { user_verification: 'discouraged' },
          rp: { name: 'GitLab' }
        )
        options_for_create.challenge
      end
    end

    def device_response
      client.create(challenge: challenge).to_json # rubocop:disable Rails/SaveBang
    end

    it 'update failed_attempts when proper password is not given' do
      go
      expect(user.failed_attempts).to be_eql(1)
    end

    context "when valid password is given" do
      it "registers and render OTP backup codes" do
        post :create_webauthn, params: params_with_password
        expect(user.otp_backup_codes).not_to be_empty
        expect(flash[:notice]).to match(/Your WebAuthn device was registered!/)
      end

      it 'registers and redirects back if user is already having backup codes' do
        expect(user).to receive(:otp_backup_codes?).and_return(true)
        post :create_webauthn, params: params_with_password
        expect(response).to redirect_to(profile_two_factor_auth_path)
        expect(flash[:notice]).to match(/Your WebAuthn device was registered!/)
      end
    end

    context "when the feature flag 'webauthn_without_totp' is disabled" do
      before do
        stub_feature_flags(webauthn_without_totp: false)
        session[:challenge] = challenge
      end

      let(:params) { { device_registration: { name: 'touch id', device_response: device_response } } } # rubocop:disable Rails/SaveBang

      it "does not validate the current_password" do
        go

        expect(flash[:notice]).to match(/Your WebAuthn device was registered!/)
        expect(response).to redirect_to(profile_two_factor_auth_path)
      end
    end
  end

  describe 'DELETE destroy' do
    def go
      delete :destroy, params: { current_password: current_password }
    end

    let(:current_password) { user.password }

    context 'for a user that has 2FA enabled' do
      let_it_be_with_reload(:user) { create(:user, :two_factor) }

      it 'disables two factor' do
        go

        expect(user.reload.two_factor_enabled?).to eq(false)
      end

      it 'redirects to profile_account_path' do
        go

        expect(response).to redirect_to(profile_account_path)
      end

      it 'displays a notice on success' do
        go

        expect(flash[:notice])
          .to eq _('Two-factor authentication has been disabled successfully!')
      end

      it_behaves_like 'user must enter a valid current password'
    end

    context 'for a user that does not have 2FA enabled' do
      let_it_be_with_reload(:user) { create(:user) }

      it 'redirects to profile_account_path' do
        go

        expect(response).to redirect_to(profile_account_path)
      end

      it 'displays an alert on failure' do
        go

        expect(flash[:alert])
          .to eq _('Two-factor authentication is not enabled for this user')
      end
    end
  end
end
