# frozen_string_literal: true

module Api
  # noinspection RubyClassModuleNamingConvention
  module V1
    class HomeController < Api::V1::BaseController
      def index
        render json: { message: 'Welcome to the app!', user: current_user.email }
      end
    end
  end
end
