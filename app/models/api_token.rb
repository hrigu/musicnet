# frozen_string_literal: true

class ApiToken < ApplicationRecord
  belongs_to :user
  # before_create :generate_token
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  encrypts :token, deterministic: true

  private

  def generate_token
    self.token = Digest::MD5.hexdigest(SecureRandom.hex)
    self.active = true
  end
end
