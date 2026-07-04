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
    end
    member do
      get :stream
    end
  end
  resources :artists, only: [:index, :show]

end
