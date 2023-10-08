# frozen_string_literal: true

require 'graphiti_helper'

RSpec.describe 'playlists#create', type: :request do
  subject(:make_request) do
    jsonapi_post '/api/v2/playlists', payload
  end

  describe 'basic create' do
    let(:params) do
      {
        name: 'fusion yellow',
        public: true
      }
    end
    let(:payload) do
      {
        data: {
          type: 'playlists',
          attributes: params
        }
      }
    end

    it 'works' do
      expect(PlaylistResource).to receive(:build).and_call_original
      expect do
        make_request
        expect(response.status).to eq(201), response.body
      end.to change { Playlist.count }.by(1)
    end
  end
end
