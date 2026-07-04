# frozen_string_literal: true

require "rails_helper"

RSpec.describe "QueueEntries", type: :request do
  fixtures :users

  let(:album) { Album.create!(spotify_id: "alb-qec-1", name: "Album") }

  def create_track(name:, spotify_id:)
    Track.create!(name: name, spotify_id: spotify_id, album: album, duration_ms: 200_000)
  end

  before { sign_in users(:one) }

  describe "POST /queue_entries" do
    it "legt einen Eintrag an" do
      track = create_track(name: "Song", spotify_id: "qec-1")

      expect do
        post queue_entries_path(track_id: track.id), as: :turbo_stream
      end.to change(QueueEntry, :count).by(1)

      expect(QueueEntry.last.track).to eq(track)
    end

    it "ignoriert den Request still, wenn die Queue bereits voll ist" do
      5.times { |n| QueueEntry.create!(track: create_track(name: "Voll #{n}", spotify_id: "qec-voll-#{n}")) }
      track = create_track(name: "Ueberzaehlig", spotify_id: "qec-ueberzaehlig")

      expect do
        post queue_entries_path(track_id: track.id), as: :turbo_stream
      end.not_to change(QueueEntry, :count)

      expect(response).to have_http_status(:success)
    end
  end

  describe "DELETE /queue_entries/:id" do
    it "entfernt den Eintrag" do
      track = create_track(name: "Song", spotify_id: "qec-2")
      entry = QueueEntry.create!(track: track)

      expect do
        delete queue_entry_path(entry), as: :turbo_stream
      end.to change(QueueEntry, :count).by(-1)
    end
  end

  describe "POST /queue_entries/advance" do
    it "entnimmt den aeltesten Eintrag und liefert die Track-Infos" do
      artist = Artist.create!(name: "Advance Artist", spotify_id: "qec-artist-1")
      track = create_track(name: "Advance Song", spotify_id: "qec-3")
      track.artists << artist
      entry = QueueEntry.create!(track: track)

      expect do
        post advance_queue_entries_path
      end.to change(QueueEntry, :count).by(-1)

      expect(QueueEntry.exists?(entry.id)).to be false
      json = response.parsed_body
      expect(json["name"]).to eq("Advance Song")
      expect(json["artist"]).to eq("Advance Artist")
      expect(json["url"]).to eq(stream_track_path(track.id))
    end

    it "entnimmt den am laengsten wartenden Eintrag zuerst (FIFO)" do
      older = create_track(name: "Aelter", spotify_id: "qec-4")
      newer = create_track(name: "Neuer", spotify_id: "qec-5")
      QueueEntry.create!(track: older, created_at: 1.minute.ago)
      QueueEntry.create!(track: newer, created_at: Time.current)

      post advance_queue_entries_path

      expect(response.parsed_body["name"]).to eq("Aelter")
    end

    it "liefert 204, wenn die Queue leer ist" do
      post advance_queue_entries_path

      expect(response).to have_http_status(:no_content)
    end
  end

  describe "POST /queue_entries/save_as_playlist" do
    it "legt eine lokale Playlist mit den gequeueten Tracks in Reihenfolge an, ohne die Queue zu leeren" do
      first = create_track(name: "Erster", spotify_id: "qec-6")
      second = create_track(name: "Zweiter", spotify_id: "qec-7")
      QueueEntry.create!(track: first, created_at: 1.minute.ago)
      QueueEntry.create!(track: second, created_at: Time.current)

      expect do
        post save_as_playlist_queue_entries_path, params: { name: "Meine Queue-Playlist" }
      end.to change(Playlist, :count).by(1).and change(QueueEntry, :count).by(0)

      playlist = Playlist.find_by(name: "Meine Queue-Playlist")
      expect(playlist.spotify_id).to be_nil
      expect(playlist.tracks).to eq([first, second])
    end
  end
end
