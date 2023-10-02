require  'graphiti_helper'

RSpec.describe PlaylistResource, type: :resource do
  fixtures :playlists

  describe 'serialization' do
    let!(:playlist) { playlists(:dark) }

    it 'works' do
      render
      data = jsonapi_data[0]
      expect(data.jsonapi_type).to eq('playlists')
      names = jsonapi_data.map{|p| p.attributes["name"]}
      expect(names).to include(playlist.name)
    end
  end

  describe 'filtering' do
    let!(:playlist1) { playlists(:dark) }
    let!(:playlist2) { playlists(:bright) }

    context 'by id' do
      before do
        params[:filter] = { id: { eq: playlist2.id } }
      end

      it 'works' do
        render
        expect(d.map(&:id)).to eq([playlist2.id])
      end
    end
  end

  describe 'sorting' do
    describe 'by id' do
      let!(:playlist1) { playlists(:dark) }
      let!(:playlist2) { playlists(:bright) }

      context 'when ascending' do
        before do
          params[:sort] = 'id'
        end

        it 'works' do
          render

          expected_ids = [playlist1.id, playlist2.id].sort!
          expect(d.map(&:id)).to eq(expected_ids)
        end
      end

      context 'when descending' do
        before do
          params[:sort] = '-id'
        end

        it 'works' do
          render
          expected_ids = [playlist1.id, playlist2.id].sort!.reverse!
          expect(d.map(&:id)).to eq(expected_ids)
        end
      end
    end
  end

  describe 'sideloading' do
    # ... your tests ...
  end
end
