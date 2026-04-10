class Project < ApplicationRecord
  belongs_to :user
  belongs_to :client
  has_many :time_entries, dependent: :destroy

  validates :name, presence: true
  validates :user_id, presence: true
  validates :client_id, presence: true

  scope :for_user, ->(user) { user.admin? ? all : where(user_id: user.id) }
  scope :active, -> { where(active: true) }
end
