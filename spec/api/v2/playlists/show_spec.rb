# frozen_string_literal: true

require 'graphiti_helper'

RSpec.describe 'playlists#show', type: :request do
  fixtures :playlists

  let(:params) { {} }
  let!(:playlist) { playlists(:dark) }

  subject(:make_request) do
    jsonapi_get "/api/v2/playlists/#{playlist.id}", params: params
  end

  describe 'basic fetch' do
    it 'works' do
      expect(PlaylistResource).to receive(:find).and_call_original
      make_request
      expect(response.status).to eq(200)
      expect(d.jsonapi_type).to eq('playlists')
      expect(d.id).to eq(playlist.id)
    end
  end
end
