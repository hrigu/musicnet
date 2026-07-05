require "rails_helper"

RSpec.describe "DSL-Suche Autocomplete (Intent 43)", type: :system do
  fixtures :users

  before { login_as(users(:one), scope: :user) }

  it "schlägt einen passenden Genre-Wert vor und übernimmt ihn per Klick ins Suchfeld" do
    create_playable_track("RSpec Autocomplete Track", spotify_id: "ac-track")
    Track.find_by(spotify_id: "ac-track").update!(genre: "RSpec Zzyzxjazz")

    visit tracks_path
    fill_in "q", with: "genre:zzyzxja"

    within(".search-suggestions-list") do
      expect(page).to have_button('genre:"RSpec Zzyzxjazz"')
      click_button 'genre:"RSpec Zzyzxjazz"'
    end

    expect(find_field("q").value).to eq('genre:"RSpec Zzyzxjazz" ')
  end
end
