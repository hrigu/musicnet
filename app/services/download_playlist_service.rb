class DownloadPlaylistService
  TRACKS_DIR = 'downloads/tracks'

  def initialize user, playlist
    @user = user
    @playlist = playlist

  end

  # lädt die Songs der @playlist runter und speichert sie unter downloads/tracks.
  # Tracks die schon vorhanden sind werden nicht nochmals runtergeladen
  def download
    tracks_dir = Rails.root.join(TRACKS_DIR)
    Rails.logger.info "DownloadPlaylistService#download: current_dir = #{tracks_dir}"
    Dir.chdir tracks_dir
    result = system( build_command )
    Rails.logger.info(result)
  end


  private

  def build_command
    o = {
      main_option: 'sync', #Removes songs that are no longer present, downloads new ones
      save_file: "--save-file #{@playlist.name_path_ready}.spotdl", #The file to save/load the songs data from/to. It has to end with .spotdl. If combined with the download operation, it will save the songs data to the file. Required for save/preload/sync
      sync_without_deleting: '--sync-without-deleting', #Sync without deleting songs that are not in the query.
      user_auth: '--user-auth',           #Login to Spotify using OAuth.
      format: '--format m4a'
  }

    playlist_url = @playlist.url
    playlist_url = "https://open.spotify.com/playlist/#{@playlist.spotify_id}" unless playlist_url
    #cmd = "spotdl #{o[:main_option]} #{o[:save_file]}  #{o[:format]} #{playlist_url}"

    cmd = "spotdl #{o[:main_option]} #{playlist_url} #{o[:save_file]} #{o[:user_auth]} #{o[:format]}"
    Rails.logger.info cmd
    cmd
  end


end
