# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RSpotify do
  context 'authenticate' do
    it 'Die App kann sich authentisieren' do
      client_id = Rails.application.credentials.dig(:spotify, :client_id)
      client_secret = Rails.application.credentials.dig(:spotify, :client_secret)
      puts client_id
      time = Benchmark.realtime {
        result = RSpotify.authenticate(client_id, client_secret)
        expect(result).to be true
      }
      puts time
    end
  end
end
