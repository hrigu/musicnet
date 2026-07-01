# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Users", type: :request do
  before { OmniAuth.config.test_mode = true }

  after { OmniAuth.config.mock_auth[:spotify] = nil }

  describe "GET /users/auth/spotify/callback" do
    it "loggt einen neuen User ein und redirected" do
      OmniAuth.config.mock_auth[:spotify] = OmniAuth::AuthHash.new(
        provider: "spotify",
        uid: "spotify-uid-neu",
        info: { email: "neu@musicnet.org" },
        extra: {}
      )

      get user_spotify_omniauth_callback_path

      expect(User.find_by(uid: "spotify-uid-neu")).to be_present
    end
  end
end
