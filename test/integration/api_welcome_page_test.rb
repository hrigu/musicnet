# frozen_string_literal: true

require 'test_helper'

class ApiWelcomePageTest < ActionDispatch::IntegrationTest
  test 'when auth token is invalid' do
    get api_v1_home_index_path, headers: { HTTP_AUTHORIZATION: 'Token token=123' }
    assert_includes request.headers['HTTP_AUTHORIZATION'], '123'
    assert_response :unauthorized
    assert_includes response.body, 'Bad credentials'
  end

  test 'with valid auth token' do
    user = User.create!(email: "huhu@optor.ch", password: "hihihihii")
    api_token = user.api_tokens.create!
    raw_token = api_token.token
    get api_v1_home_index_path, headers: { HTTP_AUTHORIZATION: "Token token=#{raw_token}" }
    assert_response :success
    assert_includes response.body, 'Welcome to the app'
    assert_includes response.body, api_token.user.email
  end

end
