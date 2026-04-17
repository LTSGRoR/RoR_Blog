Rails.application.routes.draw do
  scope "(:locale)", locale: /en|vi|ja/ do
    devise_for :users, controllers: { registrations: "users/registrations" }
    # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

    # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
    # Can be used by load balancers and uptime monitors to verify that the app is live.
    get "up" => "rails/health#show", as: :rails_health_check

    # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
    # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
    # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "posts#index"
  resources :tags, only: [:index, :create]
  resources :reactions, only: [:create]
  resources :users, only: [:show, :index] do
    member do
      post :ban
      post :unban
      post :suspend
      post :unsuspend
    end
  end

    resources :posts do
      collection do
        get :community
        get :mine
      end

      resources :comments, only: [:create]
      resource :revision, controller: :post_revisions, only: [:new, :create, :edit, :update] do
        post :submit
        post :withdraw
      end

      member do
        post :verify
        post :unverify
        post :reply_feedback
      end
    end

    namespace :admin do
      resources :posts, only: [:index]
      resources :post_revisions, only: [:show, :destroy] do
        member do
          post :approve
          post :reject
        end
      end
    end

    # Sidekiq Web UI — admin-only in all environments
    authenticate :user, ->(u) { u.admin? } do
      begin
        require "sidekiq/web"
        mount Sidekiq::Web => "/sidekiq"
      rescue LoadError
      end
    end
  end
  post '/set_locale', to: 'locales#create', as: :set_locale
end
