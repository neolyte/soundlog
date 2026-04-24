Rails.application.routes.draw do
  # Authentication
  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Root
  root "dashboard#index"

  # Resources
  resources :clients do
    resources :projects, only: [:index, :new, :create]
  end
  resources :users, only: [:index, :new, :create, :edit, :update]
  resources :projects, only: [:index, :new, :create, :show, :edit, :update, :destroy]
  resources :time_entries
  resource :timer, only: [:create, :update, :destroy] do
    patch :pause
    patch :resume
  end
end
