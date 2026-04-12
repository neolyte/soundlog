class Project < ApplicationRecord
  belongs_to :user
  belongs_to :client
  has_many :time_entries, dependent: :destroy

  validates :name, presence: true
  validates :user_id, presence: true
  validates :client_id, presence: true
  validates :total_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_user, ->(user) { user.admin? ? all : where(user_id: user.id) }
  scope :active, -> { where(active: true) }
  scope :ordered_by_recent_activity, lambda {
    left_joins(:time_entries)
      .group("projects.id")
      .order(Arel.sql("COALESCE(MAX(time_entries.created_at), projects.created_at) DESC"))
  }

  def total_hours_logged
    if time_entries.loaded?
      time_entries.sum(&:hours)
    else
      time_entries.sum(:hours)
    end
  end

  def remaining_hours
    return unless total_hours.present?

    total_hours - total_hours_logged
  end
end
