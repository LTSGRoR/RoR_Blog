Rails.application.routes.draw do
  scope "(:locale)", locale: /en|vi|ja/ do
    devise_for :users, controllers: { registrations: "users/registrations", sessions: "users/sessions" }

    get "up" => "rails/health#show", as: :rails_health_check

    root "pages#landing"
    get "blog", to: "posts#index", as: :blog
    get "team", to: "pages#team", as: :team

    # Standalone chat (no post context)
    post "chat", to: "chat#create", as: :chat
    get "chat/:id", to: "chat#show", as: :chat_status

    resources :tags, only: [ :index, :create ]
    resources :reactions, only: [ :create ]
    resources :users, only: [ :show, :index ] do
      member do
        post :ban
        post :unban
        post :suspend
        post :unsuspend
      end
    end

    resources :posts do
      collection do
        get :mine
      end

      resources :comments, only: [ :create ] do
        member do
          get :reply
          get :replies
        end
      end

      resource :revision, controller: :post_revisions, only: [ :new, :create, :edit, :update ] do
        post :submit
        post :withdraw
      end

      member do
        post :verify
        post :unverify
        post :reply_feedback
        post :chat, to: "chat#create"
      end
    end

    namespace :admin do
      resources :posts, only: [ :index ] do
        member do
          post :rerun_ai_review
        end
      end
      resource :moderation_setting, only: [ :edit, :update ]
      resources :post_revisions, only: [ :show, :destroy ] do
        member do
          post :approve
          post :reject
        end
      end
    end

    authenticate :user, ->(u) { u.admin? } do
      begin
        require "sidekiq/web"
        mount Sidekiq::Web => "/sidekiq"
      rescue LoadError
      end
    end
  end

  post "/set_locale", to: "locales#create", as: :set_locale
end
