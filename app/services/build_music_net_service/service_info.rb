# frozen_string_literal: true

class BuildMusicNetService
  class ServiceInfo
    attr_reader :hash

    def initialize
      @hash = {}
    end

    def add_new_created_playlist(name)
      add(playlists: { created: name })
    end

    def add_new_created_track(name)
      add(tracks: { created: name })
    end

    def add_new_created_album(name)
      add(albums: { created: name })
    end

    def add_new_created_artist(name)
      add(artists: { created: name })
    end

    def add_renamed_playlist(old_name, new_name)
      add(playlists: { renamed: [old_name, new_name] })
    end

    # what is a hash mit einem Eintrag {playlists: {created: "yz"})}
    def add(what)
      key = what.keys.first
      @hash[key] = {} unless @hash.key? key
      hash_value = @hash[key]
      value = what[key] # ist ein hash

      value.each do |k, v|
        hash_value[k] = [] unless hash_value.key? k
        hash_value[k] << v
      end
    end
  end
end
