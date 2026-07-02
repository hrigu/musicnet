Rails.application.routes.draw do


  devise_for :users, controllers: { omniauth_callbacks: 'users' }

  root "tracks#recently_played_index"

  resources :playlists do
    collection do
      get 'fetch_all'
    end
    member do
      get :download
      get :refresh
    end
  end

  resources :tracks, only: [:index, :show] do
    collection do
      get :recently_played_index
      get :download
    end
    member do
      get :stream
    end
  end
  resources :artists, only: [:index, :show]

end
