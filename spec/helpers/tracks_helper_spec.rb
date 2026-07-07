# frozen_string_literal: true

require "rails_helper"

RSpec.describe TracksHelper, type: :helper do
  describe "#artist_names_for" do
    it "verbindet die Namen aller Künstler eines Tracks mit Komma" do
      album = Album.create!(spotify_id: "alb-th-1", name: "Album")
      artist_a = Artist.create!(spotify_id: "art-th-1", name: "Artist A")
      artist_b = Artist.create!(spotify_id: "art-th-2", name: "Artist B")
      track = Track.create!(spotify_id: "trk-th-1", name: "Track", album: album, artists: [artist_a, artist_b],
                            duration_ms: 200_000)

      expect(helper.artist_names_for(track)).to eq("Artist A, Artist B")
    end
  end

  describe "#playlist_names_for" do
    it "verbindet die Kurznamen aller Playlists eines Tracks mit Komma" do
      album = Album.create!(spotify_id: "alb-th-2", name: "Album")
      track = Track.create!(spotify_id: "trk-th-2", name: "Track", album: album, duration_ms: 200_000)
      playlist_a = Playlist.create!(spotify_id: "pl-th-1", name: "Fusion Dark")
      playlist_b = Playlist.create!(spotify_id: "pl-th-2", name: "Blues Bright")
      PlaylistTrack.create!(playlist: playlist_a, track: track, added_at: Time.current)
      PlaylistTrack.create!(playlist: playlist_b, track: track, added_at: Time.current)

      expected = "#{helper.playlist_short_name(playlist_a)}, #{helper.playlist_short_name(playlist_b)}"
      expect(helper.playlist_names_for(track)).to eq(expected)
    end

    it "funktioniert auch, wenn nur playlists statt playlist_tracks preloaded wurde" do
      album = Album.create!(spotify_id: "alb-th-3", name: "Album")
      track = Track.create!(spotify_id: "trk-th-3", name: "Track", album: album, duration_ms: 200_000)
      playlist = Playlist.create!(spotify_id: "pl-th-3", name: "Fusion Only")
      PlaylistTrack.create!(playlist: playlist, track: track, added_at: Time.current)

      reloaded = Track.preload(:playlists).find(track.id)

      expect(helper.playlist_names_for(reloaded)).to eq(helper.playlist_short_name(playlist))
    end
  end

  describe "#track_tag_badge" do
    it "zeigt ein neutrales Badge, wenn die Kategorie keine Farbe hat" do
      category = Category.create!(name: "RSpec Kategorie Neutral")
      tag = category.tags.create!(name: "RSpec Tag Neutral", aliases: "x")
      album = Album.create!(spotify_id: "alb-th-badge-1", name: "Album")
      track = Track.create!(spotify_id: "trk-th-badge-1", name: "Track", album: album, duration_ms: 200_000)
      track_tag = TrackTag.create!(track: track, tag: tag, strength: 5)

      badge = helper.track_tag_badge(track_tag)

      expect(badge).to include("text-bg-light")
      expect(badge).to_not include("background-color")
    end

    it "leitet aus der Kategorie-Farbe einen zarten, tag-individuellen HSL-Ton ab" do
      category = Category.create!(name: "RSpec Kategorie Farbe", color: "#4a90d9")
      tag_a = category.tags.create!(name: "RSpec Tag A", aliases: "x")
      tag_b = category.tags.create!(name: "RSpec Tag B", aliases: "y")
      album = Album.create!(spotify_id: "alb-th-badge-2", name: "Album")
      track = Track.create!(spotify_id: "trk-th-badge-2", name: "Track", album: album, duration_ms: 200_000)
      track_tag_a = TrackTag.create!(track: track, tag: tag_a, strength: 5)
      track_tag_b = TrackTag.create!(track: track, tag: tag_b, strength: 5)

      badge_a = helper.track_tag_badge(track_tag_a)
      badge_b = helper.track_tag_badge(track_tag_b)

      hue_a = badge_a[/hsl\((\d+),/, 1]
      hue_b = badge_b[/hsl\((\d+),/, 1]
      aggregate_failures do
        expect(badge_a).to include("hsl(")
        expect(hue_a).to eq(hue_b), "beide Tags derselben Kategorie sollten denselben Farbton (Hue) teilen"
        expect(badge_a).to_not eq(badge_b), "unterschiedliche Tag-Namen sollten sich in der Helligkeit unterscheiden"
      end
    end

    it "funktioniert auch mit einer 3-stelligen Hex-Kurzform" do
      category = Category.create!(name: "RSpec Kategorie Kurzform", color: "#c9f")
      tag = category.tags.create!(name: "RSpec Tag Kurzform", aliases: "x")
      album = Album.create!(spotify_id: "alb-th-badge-3", name: "Album")
      track = Track.create!(spotify_id: "trk-th-badge-3", name: "Track", album: album, duration_ms: 200_000)
      track_tag = TrackTag.create!(track: track, tag: tag, strength: 5)

      expect { helper.track_tag_badge(track_tag) }.to_not raise_error
    end
  end

  describe "#tag_badge" do
    it "zeigt dieselbe abgeleitete Farbe wie track_tag_badge, aber ohne Stärke" do
      category = Category.create!(name: "RSpec Kategorie Admin", color: "#4a90d9")
      tag = category.tags.create!(name: "RSpec Tag Admin", aliases: "x")

      badge = helper.tag_badge(tag)

      expect(badge).to include("hsl(")
      expect(badge).to_not include("·")
    end
  end
end
