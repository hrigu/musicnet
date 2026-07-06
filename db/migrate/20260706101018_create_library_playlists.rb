class CreateLibraryPlaylists < ActiveRecord::Migration[8.1]
  def change
    create_table :library_playlists do |t|
      t.references :library, null: false, foreign_key: true
      t.references :playlist, null: false, foreign_key: true

      t.timestamps
    end
    add_index :library_playlists, %i[library_id playlist_id], unique: true
  end
end
