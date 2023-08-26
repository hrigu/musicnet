# frozen_string_literal: true

class TableReflex < ApplicationReflex
  def sort
    playlists = Playlist.order("#{element.dataset.column} #{element.dataset.direction}")
    morph '#playlists', render(partial: 'playlists', locals: { playlists: playlists })
  end
end

