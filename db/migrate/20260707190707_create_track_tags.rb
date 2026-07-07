class CreateTrackTags < ActiveRecord::Migration[8.1]
  def change
    create_table :track_tags do |t|
      t.references :track, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
      # 1-10, wie stark der Tag auf diesen Track zutrifft - haeufigkeitsbasiert ueber die
      # Anzahl Playlists, die auf denselben Tag matchen (Intent 77).
      t.integer :strength, null: false

      t.timestamps
    end
    add_index :track_tags, %i[track_id tag_id], unique: true
  end
end
