require 'swagger_helper'

RSpec.describe 'api/v1/playlists', type: :request do
  fixtures :api_tokens
  fixtures :playlists

  path '/api/v1/playlists' do
    get 'retrieves playlists' do
      tags 'Playlist'
      # 2) Apply the security globally to all operations
      #security [bearerAuth: []]

      produces 'application/json'
      response '200', 'playlists found' do
        schema type: :array,
               items: {
                 type: :object, properties: {
                   id: { type: :integer },
                   name: { type: :string },
                 }
               }
        #let(:api_token) {api_tokens(:one)}
        #let(:Authorization) { "HTTP_AUTHORIZATION: Token token=#{api_token.token}" }
        run_test!
      end

    end
  end

  path "/api/v1/playlists/{id}" do
    get 'Retrieves a playlist' do
      tags 'Playlist'
      produces 'application/json'
      parameter name: :id, in: :path, type: :string
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
