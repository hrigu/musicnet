Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: 'users' }

  root "tracks#recently_played"
  get "/tracks", to: "tracks#recently_played"


  resources :playlists
  #post '/auth/:provider/callback', to: 'sessions#create'
  #get '/auth/spotify/callback', to: 'users#spotify'

  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
end
