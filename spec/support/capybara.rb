# frozen_string_literal: true

# System-Specs mit echtem Browser via Cuprite (steuert Chrome per CDP an, kein
# Selenium/separater Webdriver noetig). Startet eine eigene, isolierte Chrome-Instanz -
# nicht das normale, vom Nutzer genutzte Chrome.
require "capybara/rails"
require "capybara/rspec"
require "capybara/cuprite"

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1200, 800],
    process_timeout: 15,
    headless: ENV["HEADLESS"] != "0"
  )
end

Capybara.default_max_wait_time = 5
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite

RSpec.configure do |config|
  config.before(:each, type: :system) { driven_by :cuprite }

  # login_as funktioniert auch mit einem echten Browser-Treiber, da Capybara den Rails-Server
  # fuer System-Specs im selben Ruby-Prozess laufen laesst (geteilter Warden-Test-Mode-Zustand).
  config.include Warden::Test::Helpers, type: :system
  config.before(:each, type: :system) { Warden.test_mode! }
  config.after(:each, type: :system) { Warden.test_reset! }
end
