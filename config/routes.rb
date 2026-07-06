Rails.application.routes.draw do


  devise_for :users, controllers: { omniauth_callbacks: 'users' }

  root "tracks#recently_played_index"

  resources :playlists do
    collection do
      post 'fetch_all'
    end
    member do
      post :download
      post :refresh
    end
  end

  resources :tracks, only: [:index, :show] do
    collection do
      get :recently_played_index
      post :download
      get :query_suggestions
    end
    member do
      get :stream
    end
  end
  resources :artists, only: [:index, :show]
  resources :libraries, except: [:show]

  get "help/:page", to: "help#show", as: :help

  resource :settings, only: %i[edit update]

  resources :queue_entries, only: [:create, :destroy] do
    collection do
      post :advance
      post :save_as_playlist
    end
  end

end
