# frozen_string_literal: true

module Api

  # noinspection RubyClassModuleNamingConvention
  module V2
    # TODO: in Planik ist die SUperklasse ActionController::API
    class ApplicationController < ActionController::API
      include Graphiti::Rails::Responders
    end
  end
end
