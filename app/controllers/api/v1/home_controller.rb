# frozen_string_literal: true

class Api::V1::HomeController < ActionController::Base
  def index
    render json: { message: "Welcome to the app!" }
  end
end