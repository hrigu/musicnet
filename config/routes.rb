Rails.application.routes.draw do


  devise_for :users, controllers: { omniauth_callbacks: 'users' }

  root "tracks#recently_played_index"

  resources :playlists, only: [:index, :show] do
    collection do
      get 'fetch_all'
    end
    member do
      get :download
    end
  end

  resources :tracks, only: [:index, :show] do
    collection do
      get :recently_played_index
    end
    member do
      get :play
      get :stream
    end
  end
  resources :artists, only: [:index, :show]


  namespace :api do
    namespace :v1 do
      defaults format: :json do
        get "home/index", to: "home#index" # /api/v1/home/index
        resources :playlists, only: [:index, :show]
      end
    end
    namespace :v2 do
      defaults format: :jsonapi do
        resources :playlists
      end
    end
  end

  # vandal: Graphiti API
  # Wird nicht gefunden auf http://0.0.0.0:3001/api/v2/vandal
  scope path: ApplicationResource.endpoint_namespace, defaults: { format: :jsonapi } do
    resources :playlists
    mount VandalUi::Engine, at: '/vandal'
    # your routes go here
  end


  #http://0.0.0.0:3001/api-docs/index.html
  mount Rswag::Ui::Engine => '/api-docs'
  mount Rswag::Api::Engine => '/api-docs'


end
