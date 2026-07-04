# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_04_191007) do
  create_table "albums", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "popularity"
    t.date "release_date"
    t.string "spotify_id"
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "artists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "popularity"
    t.string "spotify_id"
    t.datetime "updated_at", null: false
  end

  create_table "artists_tracks", id: false, force: :cascade do |t|
    t.integer "artist_id", null: false
    t.integer "track_id", null: false
    t.index ["artist_id"], name: "index_artists_tracks_on_artist_id"
    t.index ["track_id"], name: "index_artists_tracks_on_track_id"
  end

  create_table "playlist_tracks", force: :cascade do |t|
    t.datetime "added_at", precision: nil
    t.datetime "created_at", null: false
    t.integer "playlist_id", null: false
    t.integer "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["playlist_id"], name: "index_playlist_tracks_on_playlist_id"
    t.index ["track_id"], name: "index_playlist_tracks_on_track_id"
  end

  create_table "playlists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.boolean "public"
    t.string "snapshot_id"
    t.string "spotify_id"
    t.integer "tracks_count", default: 0, null: false
    t.datetime "updated_at", null: false
    t.string "url"
  end

  create_table "queue_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["track_id"], name: "index_queue_entries_on_track_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.integer "album_id", null: false
    t.json "audio_features"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "genre"
    t.string "name"
    t.integer "popularity"
    t.string "spotify_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["album_id"], name: "index_tracks_on_album_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "provider"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.json "spotify_user_data"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "playlist_tracks", "playlists", on_delete: :cascade
  add_foreign_key "playlist_tracks", "tracks", on_delete: :cascade
  add_foreign_key "queue_entries", "tracks"
  add_foreign_key "tracks", "albums", on_delete: :cascade
end
