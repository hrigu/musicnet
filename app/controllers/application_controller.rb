# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Pagy::Method

  before_action :authenticate_user!
end
