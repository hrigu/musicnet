# frozen_string_literal: true

class AddActivePlaylistCategoryToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :active_playlist_category, :string, default: "all", null: false
  end
end
