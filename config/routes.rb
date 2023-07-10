Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users' }

  root "tracks#recently_played_index"

  resources :playlists, only: [:index, :show] do
    collection do
      get 'fetch_all'
    end
  end

  resources :tracks, only: [:index, :show] do
    collection do
      get :recently_played_index
    end
  end
  resources :artists, only: [:index, :show]
  #post '/auth/:provider/callback', to: 'sessions#create'
  #get '/auth/spotify/callback', to: 'users#spotify'

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
