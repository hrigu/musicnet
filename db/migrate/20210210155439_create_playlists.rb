class CreatePlaylists < ActiveRecord::Migration[6.1]
  def change
    create_table :playlists do |t|
      t.string :spotify_id
      t.string :snapshot_id
      t.string :name
      t.string :url
      t.boolean :public

      t.timestamps
    end
  end
end
