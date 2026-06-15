Rails.application.routes.draw do
  # Authentication
  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  patch  "admin_view_mode", to: "sessions#update_view_mode"

  # Root
  root "dashboard#index"

  # Resources
  resource :account, only: [:edit, :update]
  resources :clients do
    resources :projects, only: [:index, :new, :create]
  end
  resources :users, only: [:index, :new, :create, :edit, :update]
  resources :projects, only: [:index, :new, :create, :show, :edit, :update, :destroy] do
    resources :retainer_periods, only: [:index, :create, :destroy], controller: "project_retainer_periods"
  end
  resources :time_entries do
    patch :update_billing_status, on: :collection
    patch :mark_unbilled, on: :member
  end
  resource :timer, only: [:create, :update, :destroy] do
    patch :pause
    patch :resume
  end
end
