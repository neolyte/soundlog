class Client < ApplicationRecord
  belongs_to :user
  has_many :projects, dependent: :destroy

  validates :name, presence: true
  validates :user_id, presence: true

  scope :for_user, ->(user) { user.admin? ? all : where(user_id: user.id) }
end
