# frozen_string_literal: true

require 'graphiti_helper'

RSpec.describe 'playlists#destroy', type: :request do
  fixtures :playlists
  let!(:playlist) { playlists(:dark) }

  subject(:make_request) do
    jsonapi_delete "/api/v2/playlists/#{playlist.id}"
  end

  describe 'basic destroy' do
    it 'updates the resource' do
      expect(PlaylistResource).to receive(:find).and_call_original
      expect do
        make_request
        expect(response.status).to eq(200), response.body
      end.to change { Playlist.count }.by(-1)
      expect { playlist.reload }
        .to raise_error(ActiveRecord::RecordNotFound)
      expect(json).to eq('meta' => {})
    end
  end
end
