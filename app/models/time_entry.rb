class TimeEntry < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :user_id, presence: true
  validates :project_id, presence: true
  validates :date, presence: true
  validates :hours, presence: true, numericality: { greater_than: 0 }

  scope :for_user, ->(user) { user.admin? ? all : where(user_id: user.id) }
  scope :for_month, ->(date) { where(date: date.beginning_of_month..date.end_of_month) }
  scope :ordered, -> { order(date: :desc, created_at: :desc) }

  def total_hours_for_date
    TimeEntry.where(user_id:, date:).sum(:hours)
  end
end
