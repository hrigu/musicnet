require 'rails_helper'

RSpec.describe "Home", type: :request do
  describe "GET /api/v1/home/index" do
    describe 'when auth token is invalid' do
      it "returns an unauthorized status" do
        get api_v1_home_index_path, headers: { HTTP_AUTHORIZATION: 'Token token=123' }
        expect(response).to have_http_status(:unauthorized)
      end
    end
    describe 'when auth token is valid' do
      user = User.create!(email: "huhu@optor.ch", password: "hihihihii")
      api_token = user.api_tokens.create!
      raw_token = api_token.token

      it "returns an unauthorized status" do
        get api_v1_home_index_path, headers: { HTTP_AUTHORIZATION: "Token token=#{raw_token}" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Welcome to the app")
        expect(response.body).to include(api_token.user.email)
      end
    end
  end
end
