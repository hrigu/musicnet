require 'swagger_helper'

RSpec.describe 'api/v1/playlists', type: :request do
  fixtures :api_tokens
  fixtures :playlists

  path '/playlists' do
    get 'retrieves playlists' do
      tags 'Playlist'
      produces 'application/json'
      response '200', 'playlists found' do
        schema type: :array,
               properties: {
                 id: { type: :integer },
                 name: { type: :string },
               }
        run_test!
      end

    end
  end

  path "/playlists/{id}" do
    get 'Retrieves a playlist' do
      tags 'Playlist'
      produces 'application/json'
      response '200', 'playlist found' do
        schema(
          type: :object,
          properties: {
            id: { type: :integer },
            name: { type: :string },
            public: { type: :boolean }
          },
          required: ['id', 'name', 'public']
        )
        let(:id) { playlists(:dark).id }
        run_test!
      end
    end
  end

  describe "index" do
    it "liefert alle Playlists" do
      api_token = api_tokens(:one)
      playlist = playlists(:dark)
      get api_v1_playlists_path #, headers: { HTTP_AUTHORIZATION: "Token token=#{api_token.token}" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(playlist.name)
    end
  end

end
