# frozen_string_literal: true

module Groups::LdapSyncHelper
  def ldap_sync_now_button_data(group)
    {
      method: :put,
      path: sync_group_ldap_path(group),
      testid: 'sync-now-button',
      modal_attributes: {
        message: _("Warning: Synchronizing LDAP removes direct members' access."),
        title: _('Synchronize LDAP'),
        size: 'sm',
        actionPrimary: {
          text: _('Sync LDAP'),
          attributes: [{ variant: 'danger', 'data-testid': 'sync-ldap-confirm-button' }]
        },
        actionSecondary: {
          text: _('Cancel'),
          attributes: [{ variant: 'default' }]
        }
      }.to_json
    }
  end
end
