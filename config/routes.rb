Rails.application.routes.draw do
  # Admin-only Jobs dashboard
  if defined?(MissionControl::Jobs::Engine)
    mount MissionControl::Jobs::Engine, at: "/jobs"
  end
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "sessions#new"


  # Account-scoped routes
  scope "/accounts/:account_id", as: :account do
    get "dashboard", to: "dashboard#index"
    resources :insales do
      collection do
        post :order
        get :check
        get :add_order_webhook
        post :create_xml
        get :xml_source
        patch :set_product_xml
      end
    end
    resources :swatch_groups do
      member do
        get :preview
        patch :toggle_status
        get :items_picker
        get :search
      end
      collection do
        post :regenerate_json
        get :style_selector
        post :pick_style
        # post :add_item
      end
      resources :swatch_group_products do
        member do
          patch :sort
        end
      end
    end

    resources :products do
      resources :variants do
        resources :varbinds
      end
    end

    resources :clients do
      resources :varbinds
    end
    resources :products do
      resources :varbinds
    end
    resources :lists do
      resources :list_items, only: [:index, :create, :destroy]
    end
    # Optional flat endpoints for list_items API
    resources :list_items, only: [:index]
  end

  # API routes for storefront (outside account scope)
  namespace :api do
    scope "/accounts/:account_id" do
      resources :lists, only: [] do
        resources :list_items, only: [:index, :create, :destroy]
      end
    end
  end
end
