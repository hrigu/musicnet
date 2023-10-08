# frozen_string_literal: true

require 'graphiti_helper'

RSpec.describe 'playlists#update', type: :request do
  fixtures :playlists
  let!(:playlist) { playlists(:dark) }

  subject(:make_request) do
    jsonapi_put "/api/v2/playlists/#{playlist.id}", payload
  end

  describe 'basic update' do
    let(:payload) do
      {
        data: {
          id: playlist.id.to_s,
          type: 'playlists',
          attributes: {
            name: 'orange'
            # ... your attrs here
          }
        }
      }
    end

    it 'updates the resource' do
      expect(PlaylistResource).to receive(:find).and_call_original
      expect do
        make_request
        expect(response.status).to eq(200), response.body
      end.to(change { playlist.reload.attributes })
    end
  end
end
