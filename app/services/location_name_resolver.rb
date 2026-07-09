# frozen_string_literal: true

require "net/http"
require "json"

# Loest Koordinaten in einen ungefaehren, menschenlesbaren Ortsnamen auf ("Zuerich" statt
# "47.376887, 8.541694") via OpenStreetMap Nominatim - kostenlos, kein API-Key/Signup, im
# Gegensatz zu Google Geocoding passend fuer dieses Single-User-Hobby-Tool (Intent 87 Nachtrag).
# Net::HTTP statt Faraday: Faraday liegt nur transitiv (ueber rspotify) im Bundle, ein direkter
# require ohne eigenen Gemfile-Eintrag waere fragil gegenueber Versionswechseln dieser
# Abhaengigkeit. Soft-Failure wie ueberall in dieser App (AudioFeaturesExtractor, Track#genre):
# jeder Fehler liefert nil statt zu raisen, nie ein User-sichtbarer 500er wegen eines externen
# Diensts.
class LocationNameResolver
  ENDPOINT = "https://nominatim.openstreetmap.org/reverse"
  USER_AGENT = "Musicnet (single-user DJ session app, https://github.com/)"
  # Nominatims Nutzungsrichtlinie verlangt max. 1 Anfrage/Sekunde.
  MIN_REQUEST_INTERVAL = 1.0
  # Adressfelder aus Nominatims "address"-Objekt, grob-nach-fein-Praeferenz fuer einen
  # Ortsnamen, der als "ungefaehrer Ort" taugt - keine Strassen/Hausnummern.
  ADDRESS_NAME_FIELDS = %w[city town village suburb municipality county state].freeze

  class << self
    attr_accessor :last_request_at
  end

  def self.resolve(latitude:, longitude:)
    new(latitude:, longitude:).resolve
  end

  def initialize(latitude:, longitude:)
    @latitude = latitude
    @longitude = longitude
  end

  def resolve
    return nil if @latitude.blank? || @longitude.blank?

    cached = cached_location_name
    return cached if cached

    throttle
    body = fetch_reverse_geocode
    extract_name(body)
  rescue StandardError => e
    Rails.logger.warn("LocationNameResolver: Aufloesung fuer (#{@latitude}, #{@longitude}) fehlgeschlagen: #{e.message}")
    nil
  end

  private

  # Koordinaten auf 3 Nachkommastellen (~110m) gerundet, damit minimal abweichende GPS-Messwerte
  # am selben Ort trotzdem den gecachten Namen wiederverwenden, statt einen neuen API-Call
  # auszuloesen - passend zum Anspruch "ungefaehrer Ort", nicht exakte Koordinate.
  def cached_location_name
    DjSessionPlayback
      .where.not(location_name: nil)
      .where("ROUND(latitude, 3) = ROUND(?, 3) AND ROUND(longitude, 3) = ROUND(?, 3)", @latitude, @longitude)
      .first&.location_name
  end

  def throttle
    last = self.class.last_request_at
    if last
      elapsed = monotonic_now - last
      sleep(MIN_REQUEST_INTERVAL - elapsed) if elapsed < MIN_REQUEST_INTERVAL
    end
    self.class.last_request_at = monotonic_now
  end

  def monotonic_now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def fetch_reverse_geocode
    uri = URI(ENDPOINT)
    uri.query = URI.encode_www_form(lat: @latitude, lon: @longitude, format: "jsonv2")

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = USER_AGENT

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 5) do |http|
      http.request(request)
    end
    return nil unless response.code == "200"

    JSON.parse(response.body)
  end

  def extract_name(body)
    address = body&.dig("address")
    return nil unless address

    field = ADDRESS_NAME_FIELDS.find { |candidate| address[candidate].present? }
    field && address[field]
  end
end
