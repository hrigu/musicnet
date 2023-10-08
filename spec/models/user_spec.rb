# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  fixtures :users
  subject { users(:one) }
  it 'hat eine Email' do
    expect(subject.email).to eql('one@musicnet.org')
  end
end
