# frozen_string_literal: true

class CreateDjSessionPlaybacks < ActiveRecord::Migration[8.1]
  def change
    create_table :dj_session_playbacks do |t|
      t.references :user, null: false, foreign_key: true
      t.references :track, null: false, foreign_key: true
      t.datetime :played_at, null: false
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.decimal :location_accuracy_meters, precision: 8, scale: 2

      t.timestamps
    end

    add_index :dj_session_playbacks, %i[user_id played_at]
    add_index :dj_session_playbacks, %i[track_id played_at]
  end
end
