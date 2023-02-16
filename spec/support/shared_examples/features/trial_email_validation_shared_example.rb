# frozen_string_literal: true

RSpec.shared_examples 'user email validation' do
  let(:email_hint_message) { 'We recommend a work email address.' }
  let(:email_error_message) { 'Please provide a valid email address.' }

  let(:email_warning_message) do
    'This email address does not look right, are you sure you typed it correctly?'
  end

  it 'shows an error message until a correct email is entered' do
    visit path
    expect(page).to have_content(email_hint_message)
    expect(page).not_to have_content(email_error_message)
    expect(page).not_to have_content(email_warning_message)

    fill_in 'new_user_email', with: 'foo@'
    fill_in 'new_user_first_name', with: ''

    expect(page).not_to have_content(email_hint_message)
    expect(page).to have_content(email_error_message)
    expect(page).not_to have_content(email_warning_message)

    fill_in 'new_user_email', with: 'foo@bar'
    fill_in 'new_user_first_name', with: ''

    expect(page).not_to have_content(email_hint_message)
    expect(page).not_to have_content(email_error_message)
    expect(page).to have_content(email_warning_message)

    fill_in 'new_user_email', with: 'foo@gitlab.com'
    fill_in 'new_user_first_name', with: ''

    expect(page).not_to have_content(email_hint_message)
    expect(page).not_to have_content(email_error_message)
    expect(page).not_to have_content(email_warning_message)
  end
end
