Rails.application.routes.draw do


  devise_for :users, controllers: { omniauth_callbacks: 'users' }

  root "tracks#recently_played_index"

  resources :playlists do
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
  end

end
