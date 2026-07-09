# frozen_string_literal: true

class TagAssignment < ApplicationRecord
  belongs_to :user
  belongs_to :tag
end
