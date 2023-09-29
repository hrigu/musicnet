require 'swagger_helper'

RSpec.describe 'api/v1/playlists', type: :request do
  fixtures :api_tokens
  fixtures :playlists

  describe "Get /api/v1/playlists/index" do
    it "liefert alle Playlists" do
      api_token = api_tokens(:one)
      playlist = playlists(:dark)
      get api_v1_playlists_path, headers: { HTTP_AUTHORIZATION: "Token token=#{api_token.token}" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(playlist.name)
    end
  end
end
