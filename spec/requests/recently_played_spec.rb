# frozen_string_literal: true

require "rails_helper"
require "ostruct"

RSpec.describe "RecentlyPlayed", type: :request do
  fixtures :users

  before { sign_in users(:one) }

  def spotify_playback(name:, played_at:, artist_name:, album_name:, popularity:)
    OpenStruct.new(
      played_at:,
      name:,
      popularity:,
      artists: [OpenStruct.new(name: artist_name)],
      album: OpenStruct.new(name: album_name)
    )
  end

  def create_recent_track(name:, spotify_id:, artist_name:)
    album = Album.create!(name: "Album #{spotify_id}", spotify_id: "alb-#{spotify_id}")
    artist = Artist.create!(name: artist_name, spotify_id: "art-#{spotify_id}")
    Track.create!(name:, spotify_id:, album:, artists: [artist], duration_ms: 200_000)
  end

  describe "GET / (recently_played_index)" do
    it "zeigt standardmässig den Musicnet-Tab aktiv" do
      get root_path

      document = Nokogiri::HTML(response.body)
      active_tab = document.css(".nav-tabs .nav-link.active").map(&:text)

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(active_tab).to eq(["Musicnet"])
      end
    end

    it "zeigt lokale Musicnet-Playbacks getrennt von anderen Usern" do
      own_track = create_recent_track(name: "RSpec Local Playback", spotify_id: "recent-local-own",
                                      artist_name: "RSpec Artist Local")
      other_track = create_recent_track(name: "RSpec Fremdes Playback", spotify_id: "recent-local-other",
                                        artist_name: "RSpec Artist Other")
      DjSessionPlayback.create!(user: users(:one), track: own_track, played_at: Time.zone.parse("2026-07-09 20:00:00"))
      DjSessionPlayback.create!(user: users(:two), track: other_track, played_at: Time.zone.parse("2026-07-09 21:00:00"))

      get root_path

      aggregate_failures do
        expect(response.body).to include("RSpec Local Playback")
        expect(response.body).to_not include("RSpec Fremdes Playback")
      end
    end

    it "verwendet den angemeldeten User für recently_played im Spotify-Tab" do
      current_spotify_user = users(:one).spotify_user
      other_spotify_user = users(:two).spotify_user
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([])
      expect(other_spotify_user).not_to receive(:recently_played)

      get root_path(tab: "spotify")

      expect(response).to have_http_status(:success)
    end

    it "zeigt Spotify-Playbacks nur im Spotify-Tab" do
      current_spotify_user = users(:one).spotify_user
      playback = spotify_playback(name: "RSpec Spotify Playback", played_at: "2026-07-09T22:00:00Z",
                                  artist_name: "RSpec Spotify Artist", album_name: "RSpec Spotify Album",
                                  popularity: 77)
      allow(current_spotify_user).to receive(:recently_played).with(limit: 50).and_return([playback])

      get root_path(tab: "spotify")

      aggregate_failures do
        expect(response.body).to include("RSpec Spotify Playback")
        expect(response.body).to include("RSpec Spotify Artist")
        expect(response.body).to include("RSpec Spotify Album")
        expect(response.body).to include("77")
      end
    end
  end
end
