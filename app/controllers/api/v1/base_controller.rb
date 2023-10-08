# frozen_string_literal: true

module Api
  # noinspection RubyClassModuleNamingConvention
  module V1
    class BaseController < ActionController::Base
      rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found

      before_action :authenticate

      attr_reader :current_user

      private

      def authenticate
        authenticate_user_with_token || handle_bad_authentication
      end

      def authenticate_user_with_token
        authenticate_with_http_token do |token, _options|
          current_api_token = ApiToken.where(active: true).find_by(token: token)
          @current_user = current_api_token.try(:user)
        end
      end

      def handle_bad_authentication
        render json: { message: 'Bad credentials' }, status: :unauthorized
      end

      def handle_not_found
        render json: { message: 'Record not found' }, status: :not_found
      end
    end
  end
end
