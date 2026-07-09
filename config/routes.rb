# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users, controllers: { omniauth_callbacks: "users" }

  root "tracks#recently_played_index"

  resources :playlists do
    collection do
      post "fetch_all"
    end
    member do
      post :download
      post :refresh
    end
  end

  resources :tracks, only: %i[index show] do
    collection do
      get :recently_played_index
      post :download
      post :import_from_spotify
      get :query_suggestions
    end
    member do
      get :cover
      get :stream
    end
  end
  resources :artists, only: %i[index show]
  resources :libraries, except: [:show]
  resources :categories, except: [:show] do
    resources :tags, except: %i[index show], controller: "tags", shallow: true
  end
  get "tags/search", to: "tags#search", as: :search_tags
  resources :dj_session_playbacks, only: [:create]
  resources :track_tags, only: %i[create update destroy]

  get "help/:page", to: "help#show", as: :help

  resource :settings, only: %i[edit update]

  resources :queue_entries, only: %i[create destroy] do
    collection do
      post :advance
      post :save_as_playlist
    end
  end

  resources :playlist_tracks, only: %i[create destroy]
end
