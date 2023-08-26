
require 'rspotify'

# Siehe Rails.application.credentials.dig(:spotify, :client_id)
# Die Credentials sind https://developer.spotify.com/dashboard/61f2f8a2eb7340e89e33723785125ca5 hinterlegt
credentials = {
  client_id: "ddd",
  client_secret: "xxx"
}


RSpotify.authenticate(credentials.dig(:client_id), credentials.dig(:client_secret))

me = RSpotify::User.find('hrigu')

# Alle öffentliche und auf das User Profil hinzugefügte Playlists.
me.playlists.each do |playlist|
  puts playlist.name
end
