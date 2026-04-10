Rails.application.routes.draw do
  # Authentication
  get    "login",  to: "sessions#new"
  post   "login",  to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Root
  root "dashboard#index"

  # Resources
  resources :clients
  resources :projects
  resources :time_entries
end
