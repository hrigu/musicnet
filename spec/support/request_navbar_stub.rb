# frozen_string_literal: true

# Die Navbar (app/views/layouts/_navbar.html.erb) ruft fuer eingeloggte User
# current_user.spotify_user.images auf - das ist ein lazy geladenes RSpotify-Attribut,
# das ohne echte Spotify-Authentifizierung einen echten API-Call ausloesen wuerde.
# In Request-Specs stubben wir #spotify_user global, damit jede Seite mit Navbar rendern kann.
RSpec.configure do |config|
  config.before(:each, type: :request) do
    fake_spotify_user = double("RSpotify::User", images: [{ "url" => "https://example.com/avatar.png" }])
    allow_any_instance_of(User).to receive(:spotify_user).and_return(fake_spotify_user)
  end
end
