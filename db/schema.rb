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

ActiveRecord::Schema[8.1].define(version: 2026_07_09_103002) do
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

  create_table "categories", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.boolean "hidden_for_assignment", default: false, null: false
    t.boolean "is_event", default: false, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "libraries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "keyword", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_libraries_on_name", unique: true
  end

  create_table "library_playlists", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "library_id", null: false
    t.integer "playlist_id", null: false
    t.datetime "updated_at", null: false
    t.index ["library_id", "playlist_id"], name: "index_library_playlists_on_library_id_and_playlist_id", unique: true
    t.index ["library_id"], name: "index_library_playlists_on_library_id"
    t.index ["playlist_id"], name: "index_library_playlists_on_playlist_id"
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
    t.string "color"
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

  create_table "tag_assignments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "tag_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["tag_id"], name: "index_tag_assignments_on_tag_id"
    t.index ["user_id", "created_at"], name: "index_tag_assignments_on_user_id_and_created_at"
    t.index ["user_id", "tag_id", "created_at"], name: "index_tag_assignments_on_user_id_and_tag_id_and_created_at"
    t.index ["user_id"], name: "index_tag_assignments_on_user_id"
  end

  create_table "tags", force: :cascade do |t|
    t.text "aliases", null: false
    t.boolean "assignable", default: true, null: false
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["category_id", "name"], name: "index_tags_on_category_id_and_name", unique: true
    t.index ["category_id"], name: "index_tags_on_category_id"
  end

  create_table "track_tags", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "strength", null: false
    t.integer "tag_id", null: false
    t.integer "track_id", null: false
    t.datetime "updated_at", null: false
    t.index ["tag_id"], name: "index_track_tags_on_tag_id"
    t.index ["track_id", "tag_id"], name: "index_track_tags_on_track_id_and_tag_id", unique: true
    t.index ["track_id"], name: "index_track_tags_on_track_id"
  end

  create_table "tracks", force: :cascade do |t|
    t.integer "album_id", null: false
    t.json "audio_features"
    t.datetime "created_at", null: false
    t.integer "duration_ms"
    t.string "file_name"
    t.string "genre"
    t.string "name"
    t.integer "popularity"
    t.string "spotify_id"
    t.datetime "updated_at", null: false
    t.string "url"
    t.index ["album_id"], name: "index_tracks_on_album_id"
  end

  create_table "users", force: :cascade do |t|
    t.integer "active_library_id"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.json "hidden_track_columns", default: [], null: false
    t.string "provider"
    t.datetime "remember_created_at", precision: nil
    t.datetime "reset_password_sent_at", precision: nil
    t.string "reset_password_token"
    t.json "spotify_user_data"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["active_library_id"], name: "index_users_on_active_library_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "library_playlists", "libraries"
  add_foreign_key "library_playlists", "playlists"
  add_foreign_key "playlist_tracks", "playlists", on_delete: :cascade
  add_foreign_key "playlist_tracks", "tracks", on_delete: :cascade
  add_foreign_key "queue_entries", "tracks"
  add_foreign_key "tag_assignments", "tags"
  add_foreign_key "tag_assignments", "users"
  add_foreign_key "tags", "categories"
  add_foreign_key "track_tags", "tags"
  add_foreign_key "track_tags", "tracks"
  add_foreign_key "tracks", "albums", on_delete: :cascade
  add_foreign_key "users", "libraries", column: "active_library_id"
end
