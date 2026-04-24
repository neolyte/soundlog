class Project < ApplicationRecord
  belongs_to :user
  belongs_to :client
  has_many :time_entries, dependent: :destroy

  validates :name, presence: true
  validates :user_id, presence: true
  validates :client_id, presence: true
  validates :total_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :for_user, lambda { |user, view_all = user.admin?|
    if view_all
      all
    else
      joins(:client).where("projects.user_id = :user_id OR clients.user_id = :user_id", user_id: user.id)
    end
  }
  scope :active, -> { joins(:client).where(projects: { active: true }, clients: { active: true }) }
  scope :archived, -> { joins(:client).where("projects.active = ? OR clients.active = ?", false, false) }
  scope :ordered_by_recent_activity, lambda {
    left_joins(:time_entries)
      .group("projects.id")
      .order(
        Arel.sql("COALESCE(MAX(time_entries.date), DATE(projects.created_at)) DESC"),
        Arel.sql("COALESCE(MAX(time_entries.created_at), projects.created_at) DESC")
      )
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

  def latest_activity_at
    if time_entries.loaded?
      time_entries.map(&:created_at).compact.max || created_at
    else
      time_entries.maximum(:created_at) || created_at
    end
  end

  def latest_time_entry
    if time_entries.loaded?
      time_entries.max_by { |entry| [entry.date || Date.new(0), entry.created_at || Time.at(0)] }
    else
      time_entries.includes(:user).order(date: :desc, created_at: :desc).first
    end
  end

  def latest_activity_sort_key
    entry = latest_time_entry
    [entry&.date || created_at.to_date, entry&.created_at || created_at]
  end

  def archived?
    !active? || client&.archived?
  end
end
