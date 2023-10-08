# frozen_string_literal: true

module Api
  # noinspection RubyClassModuleNamingConvention
  module V1
    class PlaylistsController < Api::V1::BaseController
      # Vorübergehend, damit ich die Tests besser schreiben kann
      # skip_before_action :authenticate

      def index
        @playlists = Playlist.order(:name)
        render json: @playlists
      end

      def show
        id = params[:id]
        @playlist = Playlist.find(id)
        render json: @playlist
      end
    end
  end
end
