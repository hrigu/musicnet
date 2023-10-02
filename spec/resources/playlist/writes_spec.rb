require  'graphiti_helper'

RSpec.describe PlaylistResource, type: :resource do
  fixtures :playlists
  describe 'creating' do
    let(:payload) do
      {
        data: {
          type: 'playlists',
          attributes: { name: "Fusion Sweet", public: true }
        }
      }
    end

    let(:instance) do
      PlaylistResource.build(payload)
    end

    it 'works' do
      expect {
        expect(instance.save).to eq(true), instance.errors.full_messages.to_sentence
      }.to change { Playlist.count }.by(1)
    end
  end

  describe 'updating' do
    let!(:playlist) { playlists(:dark) }

    let(:payload) do
      {
        data: {
          id: playlist.id.to_s,
          type: 'playlists',
          attributes: { name: "Fusion BLABLA", public: true }
        }
      }
    end

    let(:instance) do
      PlaylistResource.find(payload)
    end

    it 'works (add some attributes and enable this spec)' do
      expect {
        expect(instance.update_attributes).to eq(true)
      }.to change { playlist.reload.updated_at }
      .and change { playlist.name }.to('Fusion BLABLA')
    end
  end

  describe 'destroying' do
    let!(:playlist) { playlists(:dark) }

    let(:instance) do
      PlaylistResource.find(id: playlist.id)
    end

    it 'works' do
      expect {
        expect(instance.destroy).to eq(true)
      }.to change { Playlist.count }.by(-1)
    end
  end
end
