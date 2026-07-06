# frozen_string_literal: true

require "rails_helper"

RSpec.describe PlaylistsHelper, type: :helper do
  describe "#playlist_short_name" do
    it "ersetzt 'fusion'/'blues' und entfernt Leerzeichen" do
      playlist = Playlist.new(name: "Fusion Dark")

      expect(helper.playlist_short_name(playlist)).to eq("F_Dark")
    end
  end

  def hue_of(badge)
    badge[/hsl\((\d+)/, 1]&.to_i
  end

  describe "#playlist_badge" do
    it "gibt DJ-Gig-Playlists (Datum-Praefix) grau statt schwarz, unabhaengig vom Rest des Namens (Intent 71 Nachtrag)" do
      first = Playlist.new(name: "2024 Sommerfest")
      second = Playlist.new(name: "2025 Hochzeit Meyer")

      aggregate_failures do
        expect(helper.playlist_badge(first)).to include("text-bg-secondary")
        expect(helper.playlist_badge(second)).to include("text-bg-secondary")
      end
    end

    it "gibt Playlists mit demselben ersten Wort denselben Farbton (Hue), aber nicht dieselbe Helligkeit (Intent 71 Nachtrag)" do
      monday = Playlist.new(name: "Fusion Montag")
      tuesday = Playlist.new(name: "Fusion Dienstag")

      badge_monday = helper.playlist_badge(monday)
      badge_tuesday = helper.playlist_badge(tuesday)

      aggregate_failures do
        expect(hue_of(badge_monday)).to eq(hue_of(badge_tuesday))
        expect(badge_monday).to_not eq(badge_tuesday)
      end
    end

    it "ignoriert Gross-/Kleinschreibung beim ersten Wort fuer den Farbton (Intent 71 Nachtrag)" do
      lower = Playlist.new(name: "fusion Montag")
      upper = Playlist.new(name: "FUSION Dienstag")

      expect(hue_of(helper.playlist_badge(lower))).to eq(hue_of(helper.playlist_badge(upper)))
    end

    it "gibt Playlists mit unterschiedlichem ersten Wort unterschiedliche Farbtoene (Intent 71 Nachtrag)" do
      fusion = Playlist.new(name: "Fusion Montag")
      blues = Playlist.new(name: "Blues Dienstag")

      expect(hue_of(helper.playlist_badge(fusion))).to_not eq(hue_of(helper.playlist_badge(blues)))
    end

    it "nutzt die automatische Farbe ohne eigene Farbe (Intent 71)" do
      playlist = Playlist.new(name: "Fusion Dark", color: nil)

      badge = helper.playlist_badge(playlist)

      aggregate_failures do
        expect(badge).to include("hsl(")
        expect(badge).to include("F_Dark")
      end
    end

    it "nutzt die eigene Farbe als Inline-Style, wenn gesetzt (Intent 71)" do
      playlist = Playlist.new(name: "Fusion Dark", color: "#3366cc")

      badge = helper.playlist_badge(playlist)

      aggregate_failures do
        expect(badge).to include("background-color: #3366cc")
        expect(badge).to_not include("hsl(")
      end
    end

    it "waehlt schwarzen Text bei einer hellen eigenen Farbe (Intent 71)" do
      playlist = Playlist.new(name: "Hell", color: "#ffffff")

      expect(helper.playlist_badge(playlist)).to include("color: #000")
    end

    it "waehlt weissen Text bei einer dunklen eigenen Farbe (Intent 71)" do
      playlist = Playlist.new(name: "Dunkel", color: "#000000")

      expect(helper.playlist_badge(playlist)).to include("color: #fff")
    end
  end

  describe "#playlist_preview_color" do
    it "gibt die eigene Farbe zurueck, wenn gesetzt (Intent 71 Nachtrag)" do
      playlist = Playlist.new(name: "Fusion Dark", color: "#3366cc")

      expect(helper.playlist_preview_color(playlist)).to eq("#3366cc")
    end

    it "gibt einen Hex-Wert fuer die automatische Farbe zurueck, ohne eigene Farbe (Intent 71 Nachtrag)" do
      playlist = Playlist.new(name: "Fusion Dark", color: nil)

      expect(helper.playlist_preview_color(playlist)).to match(/\A#[0-9a-f]{6}\z/)
    end

    it "gibt Bootstraps Grau fuer DJ-Gig-Playlists zurueck (Intent 71 Nachtrag)" do
      playlist = Playlist.new(name: "2024 Sommerfest", color: nil)

      expect(helper.playlist_preview_color(playlist)).to eq("#6c757d")
    end
  end

  describe "#all_tracks_downloaded?" do
    it "gibt true zurück, wenn alle Tracks einen track_path haben" do
      pt1 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: "/a.m4a"))
      pt2 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: "/b.m4a"))

      expect(helper.all_tracks_downloaded?([pt1, pt2])).to be true
    end

    it "gibt false zurück, wenn mindestens ein Track keinen track_path hat" do
      pt1 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: "/a.m4a"))
      pt2 = instance_double(PlaylistTrack, track: instance_double(Track, track_path: nil))

      expect(helper.all_tracks_downloaded?([pt1, pt2])).to be false
    end

    it "gibt true zurück für eine leere Playlist" do
      expect(helper.all_tracks_downloaded?([])).to be true
    end
  end
end
