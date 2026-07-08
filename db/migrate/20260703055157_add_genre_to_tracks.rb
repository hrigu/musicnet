# frozen_string_literal: true

class AddGenreToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :genre, :string
  end
end
