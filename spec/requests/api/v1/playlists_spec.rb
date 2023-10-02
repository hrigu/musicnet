require 'swagger_helper'

RSpec.describe 'api/v1/playlists', type: :request do
  fixtures :api_tokens
  fixtures :playlists

  path '/api/v1/playlists' do
    get 'retrieves playlists' do
      tags 'Playlist'
      # 2) Apply the security globally to all operations
      security [bearerAuth: []]
      # Ein Query Parameter (wird aktuell nicht ausgewertet)
      parameter name: :order, in: :query, type: :string,
                description: "Sortierung. Wird nicht verwendet",
                required: false

      produces 'application/json'
      response '200', 'Retrieves all Playlists' do
        schema type: :array,
               items: {
                 type: :object, properties: {
                   id: { type: :integer },
                   name: { type: :string },
                   hihi: {type: :boolean} # gibt es nicht. Damit ein Fehler geworfen wird, verwende swagger_strict_schema_validation: true
                 }
               }
        let(:order) {"hoho"}
        let(:api_token) {api_tokens(:one)}
        let(:Authorization) { "Token token=#{api_token.token}" }
        let(:playlist) { playlists(:dark) }
        run_test! do |response|
          # Mit Custom Abfragen
          content = JSON.parse(response.body)
          expect(content.length).to be(Playlist.count)
          expect(content.map{|p| p["name"]}).to match_array(Playlist.all.map{|p| p.name})
        end #swagger_strict_schema_validation: true  #vcr: true
      end

    end
  end

  path "/api/v1/playlists/{id}" do
    get 'Retrieves a playlist' do
      tags 'Playlist'
      produces 'application/json'
      security [bearerAuth: []]
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
        example 'application/json', :dunkel, {
          id: 1,
          name: 'DARKK',
          public: true
        }
        example 'application/json', :hell, {
          id: 1,
          name: 'BRIGHT',
          public: false
        }
        let(:id) { playlists(:dark).id }
        let(:api_token) {api_tokens(:one)}
        let(:Authorization) { "Token token=#{api_token.token}" }
        run_test!
      end
    end
  end

  describe "index" do
    it "liefert alle Playlists" do
      api_token = api_tokens(:one)
      playlist = playlists(:dark)
      get api_v1_playlists_path, headers: { HTTP_AUTHORIZATION: "Token token=#{api_token.token}" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include(playlist.name)
    end
  end

end
