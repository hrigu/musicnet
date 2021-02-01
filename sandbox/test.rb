
require 'rspotify'


credentials = {
  client_id: "ddd",
  client_secret: "xxx"
}


RSpotify.authenticate(credentials.dig(:client_id), credentials.dig(:client_secret))

me = RSpotify::User.find('hrigu')
puts me.playlists #=> (Playlist array)
