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

    expect(find_field("q").value).to eq('genre:"RSpec Zzyzxjazz"')
  end

  it "macht das Vorschlags-Dropdown bei vielen Treffern scrollbar (Intent 55)" do
    10.times do |n|
      create_playable_track("RSpec Scroll Track #{n}", spotify_id: "ac-scroll-#{n}")
      Track.find_by(spotify_id: "ac-scroll-#{n}").update!(genre: format("RSpec Zzyscroll %02d", n))
    end

    visit tracks_path
    fill_in "q", with: "genre:zzyscroll"

    within(".search-suggestions-list") { expect(page).to have_button(count: 10) }
    heights = evaluate_script(<<~JS)
      (() => {
        const el = document.querySelector(".search-suggestions-list")
        return [el.scrollHeight, el.clientHeight]
      })()
    JS
    expect(heights.first).to be > heights.last

    page.execute_script(<<~JS)
      const el = document.querySelector(".search-suggestions-list")
      el.scrollTop = el.scrollHeight
    JS
    within(".search-suggestions-list") { click_button('genre:"RSpec Zzyscroll 09"') }

    expect(find_field("q").value).to eq('genre:"RSpec Zzyscroll 09"')
  end
end
