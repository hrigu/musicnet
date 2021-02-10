class CreateAlbums < ActiveRecord::Migration[6.1]
  def change
    create_table :albums do |t|
      t.string :spotify_id
      t.string :name
      t.string :url
      t.date :release_date
      t.integer :popularity

      t.timestamps
    end
  end
end
