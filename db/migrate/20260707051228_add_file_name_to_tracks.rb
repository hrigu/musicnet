# frozen_string_literal: true

class AddFileNameToTracks < ActiveRecord::Migration[8.1]
  def change
    add_column :tracks, :file_name, :string
  end
end
