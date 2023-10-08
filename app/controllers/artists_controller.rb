# frozen_string_literal: true

class ArtistsController < ApplicationController
  def index
    @artists = Artist.includes(:albums, :tracks).all
  end

  def show
    id = params[:id]
    @artist = Artist.find(id)
  end
end
