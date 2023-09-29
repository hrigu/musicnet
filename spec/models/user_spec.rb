require 'rails_helper'


RSpec.describe User, type: :model do
  fixtures :users
  it "hat eine Email" do
    user_one = users(:one)
    expect(user_one.email).to eql("one@musicnet.org")
  end
end
