# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  fixtures :users
  subject { users(:one) }
  it "hat eine Email" do
    expect(subject.email).to eql("one@musicnet.org")
  end

  describe ".from_omniauth" do
    it "erstellt einen neuen User, wenn noch keiner existiert" do
      auth = OmniAuth::AuthHash.new(provider: "spotify", uid: "neue-uid", info: { email: "neu@musicnet.org" })

      expect do
        User.from_omniauth(auth, "{}")
      end.to change(User, :count).by(1)
    end

    it "findet den bestehenden User anhand provider+uid, statt ein Duplikat zu erstellen" do
      existing = User.create!(email: "bestehend@musicnet.org", password: "geheim123",
                              provider: "spotify", uid: "bestehende-uid")
      auth = OmniAuth::AuthHash.new(provider: "spotify", uid: "bestehende-uid",
                                    info: { email: "irrelevant@musicnet.org" })

      result = nil
      expect do
        result = User.from_omniauth(auth, "{}")
      end.not_to change(User, :count)
      expect(result).to eq(existing)
    end

    it "aktualisiert spotify_user_data bei jedem Login, nicht nur beim Erstellen" do
      existing = User.create!(email: "bestehend@musicnet.org", password: "geheim123",
                              provider: "spotify", uid: "bestehende-uid",
                              spotify_user_data: '{"images": []}')
      auth = OmniAuth::AuthHash.new(provider: "spotify", uid: "bestehende-uid",
                                    info: { email: "irrelevant@musicnet.org" })

      User.from_omniauth(auth, '{"images": [{"url": "https://example.com/neu.jpg"}]}')

      expect(existing.reload.spotify_user_data).to eq('{"images": [{"url": "https://example.com/neu.jpg"}]}')
    end
  end

  describe "#spotify_user" do
    it "rekonstruiert ein RSpotify::User aus spotify_user_data" do
      user = User.new(spotify_user_data: { id: "spotify-id-1", display_name: "Test" }.to_json)

      expect(user.spotify_user).to be_a(RSpotify::User)
      expect(user.spotify_user.id).to eq("spotify-id-1")
    end
  end

  describe "#spotify_avatar_url" do
    it "gibt die erste Avatar-URL zurück, wenn eine vorhanden ist" do
      user = User.new(spotify_user_data: {
        id: "spotify-id-1",
        images: [{ "url" => "https://example.com/avatar.png" }]
      }.to_json)

      expect(user.spotify_avatar_url).to eq("https://example.com/avatar.png")
    end

    it "gibt nil zurück, wenn kein Avatar vorhanden ist" do
      user = User.new(spotify_user_data: { id: "spotify-id-1", images: [] }.to_json)

      expect(user.spotify_avatar_url).to be_nil
    end
  end

  describe "#active_library" do
    it "ist standardmässig nil (Alle, kein Filter)" do
      user = User.new

      expect(user.active_library).to be_nil
    end

    it "kann auf eine Library gesetzt werden" do
      library = Library.create!(name: "Fusion", keyword: "fusion")
      user = User.new(email: "cat@musicnet.org", password: "geheim123", active_library: library)

      expect(user.active_library).to eq(library)
    end
  end

  describe "#column_visible?" do
    it "ist standardmässig für jede Spalte sichtbar (leeres hidden_track_columns)" do
      user = User.new

      expect(user.column_visible?("playlists")).to be true
    end

    it "ist false für eine ausgeblendete Spalte" do
      user = User.new(hidden_track_columns: ["playlists"])

      expect(user.column_visible?("playlists")).to be false
      expect(user.column_visible?("genre")).to be true
    end
  end
end
