Rails.application.routes.draw do

  # Super-admin namespace for managing accounts and users across all accounts
  # Admin-only Jobs dashboard (mounted under /admin)
  if defined?(MissionControl::Jobs::Engine)
    namespace :admin do
      mount MissionControl::Jobs::Engine, at: "/jobs", as: :jobs
    end
  end
  namespace :admin do
    get 'dashboard', to: 'dashboard#index', as: :dashboard
    resources :users, only: [:index]
    resources :plans
    # New: super-admin payments over all accounts
    resources :payments, only: [:index, :show, :update]
    # Invoices merged into Payments (filter by processor=invoice)
    resources :accounts do
      resources :users, except: [:index, :show]
    end
  end
  
  resource :session
  resources :passwords, param: :token
  
  # Inswatch integration routes
  resource :inswatch, only: [], controller: 'inswatch' do
    get :install
    get :autologin
  end
  
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "sessions#new"
  
  # Locale switching
  get "switch_locale/:locale", to: "application#switch_locale", as: :switch_locale

  # Billing webhooks
  namespace :billing do
    namespace :paymaster do
      post 'success'
      post 'fail'
      post 'result'
    end
  end

  # Account-scoped routes (must be before accounts resources to avoid route conflicts)
  scope "/accounts/:account_id", as: :account do
    get "dashboard", to: "dashboard#index"
    resources :insales do
      member do
        get :check
        get :add_order_webhook
      end
      collection do
        post :order
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
      resources :varbinds
      member do
        get :insales_info
      end
      resources :variants do
        resources :varbinds
      end
    end

    resources :clients do
      member do
        get :insales_info
      end
      resources :varbinds
    end

    resources :lists do
      resources :list_items, only: [:index, :create, :destroy]
    end
    resources :discounts do
      member do
        patch :sort
      end
    end
    resources :incases do
      member do
        patch :update_status
      end
    end
    resources :webforms do
      member do
        get :preview
        get :schema
        patch :build
      end
      collection do
        get :info
        post :regenerate_json
      end
      resources :webform_fields, except: [:show] do
        member do
          get :design
          patch :build
          patch :sort
        end
      end
    end
    resources :automation_rules do
      member do
        get :design
        patch :build
      end
      resources :automation_conditions, only: [:new, :create, :destroy]
      resources :automation_actions, only: [:new, :create, :destroy]
    end
    resources :automation_conditions, only: [:new, :destroy]
    resources :automation_actions, only: [:new, :destroy]

    resources :message_templates
    resources :automation_messages, only: [:index]
    resources :users
    resources :subscriptions do
      member do
        patch :cancel
      end
      resources :payments, only: [:new, :create]
    end
    resources :payments, only: [:index, :show]
    resources :invoices, only: [:show]

  end


  # API routes for storefront (outside account scope)
  namespace :api do
    scope "/accounts/:account_id" do
      resources :incases, only: [:create] do
        collection do
          post :insales_order
        end
      end
      resources :lists, only: [] do
        resources :list_items, only: [:index, :create, :destroy]
      end
      resources :discounts, only: [] do
        collection do
          post :calc
        end
      end
      resources :automation_rules, only: [] do
        collection do
          get :available_fields
        end
      end
      namespace :webhooks do
        post 'insales/order', to: 'insales#order'
      end
    end
  end

end
