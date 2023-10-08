# frozen_string_literal: true

require 'graphiti_helper'

RSpec.describe 'playlists#index', type: :request do
  fixtures :playlists

  let(:params) { {} }

  subject(:make_request) do
    jsonapi_get '/api/v2/playlists', params: params
  end

  describe 'basic fetch' do
    let!(:playlist1) { playlists(:dark) }
    let!(:playlist2) { playlists(:bright) }

    it 'works' do
      expect(PlaylistResource).to receive(:all).and_call_original
      make_request
      expect(response.status).to eq(200), response.body
      expect(d.map(&:jsonapi_type).uniq).to match_array(['playlists'])
      expect(d.map(&:id)).to match_array([playlist1.id, playlist2.id])
    end
  end
end
