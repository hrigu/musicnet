# frozen_string_literal: true

class AddColorToPlaylists < ActiveRecord::Migration[8.1]
  def change
    add_column :playlists, :color, :string
  end
end
