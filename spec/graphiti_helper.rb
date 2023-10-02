# Dieses File wird benötigt für alle API-Tests
require 'rails_helper'
require 'graphiti_spec_helpers/rspec'

module GraphitiHelper

  # @auth_params muss gesetzt sein
  # Siehe https://graphiti-api.github.io/graphiti/guides/concepts/testing#api-test-helpers
  # Siehe in graphiti_spec_helpers/lib/graphiti_spec_helpers/helpers.rb
  def jsonapi_headers
    headers = { 'CONTENT_TYPE' => 'application/vnd.api+json'}
    headers.merge!(@auth_params) if @auth_params.present?
    headers
  end
end

RSpec.configure do |config|
  config.include GraphitiSpecHelpers::RSpec
  config.include GraphitiSpecHelpers::Sugar
  config.include GraphitiHelper

  config.before :each do
    #GraphitiErrors.disable!
  end
end

# https://www.graphiti.dev/guides/concepts/testing#schema-validation
GraphitiSpecHelpers::RSpec.schema!