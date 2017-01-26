resources :groups, only: [:index, :new, :create]

scope(path: 'groups/*group_id',
      module: :groups,
      as: :group,
      constraints: { group_id: Gitlab::Regex.namespace_route_regex }) do
  ## EE-specific
  resource :analytics, only: [:show]
  resource :ldap, only: [] do
    member do
      put :sync
    end
  end

  resources :ldap_group_links, only: [:index, :create, :destroy]
  ## EE-specific

  resources :group_members, only: [:index, :create, :update, :destroy], concerns: :access_requestable do
    post :resend_invite, on: :member
    delete :leave, on: :collection

    ## EE-specific
    patch :override, on: :member
    ## EE-specific
  end

  resource :avatar, only: [:destroy]
  resources :milestones, constraints: { id: /[^\/]+/ }, only: [:index, :show, :update, :new, :create]

  ## EE-specific
  resource :notification_setting, only: [:update]
  resources :audit_events, only: [:index]
  resources :pipeline_quota, only: [:index]
  ## EE-specific

  ## EE-specific
  resources :hooks, only: [:index, :create, :destroy], constraints: { id: /\d+/ } do
    member do
      get :test
    end
  end
  ## EE-specific

  resources :labels, except: [:show] do
    post :toggle_subscription, on: :member
  end
end

scope(path: 'groups/*id',
      controller: :groups,
      constraints: { id: Gitlab::Regex.namespace_route_regex, format: /(html|json|atom)/ }) do
  get :edit, as: :edit_group
  get :issues, as: :issues_group
  get :merge_requests, as: :merge_requests_group
  get :projects, as: :projects_group
  get :activity, as: :activity_group
  get '/', action: :show, as: :group_canonical
end
