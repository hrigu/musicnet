class CreateJoinTablesForArtists < ActiveRecord::Migration[6.1]
  def change
    create_join_table :albums, :artists do |t|
      t.index :album_id
      t.index :artist_id
    end
    create_join_table :tracks, :artists do |t|
      t.index :track_id
      t.index :artist_id
    end
  end
end
