class Client < ApplicationRecord
  belongs_to :user
  has_many :projects, dependent: :destroy

  validates :name, presence: true
  validates :user_id, presence: true

  scope :for_user, ->(user) { user.admin? ? all : where(user_id: user.id) }

  def active_projects
    if projects.loaded?
      projects.select(&:active?)
    else
      projects.active
    end
  end

  def active_projects_count
    active_projects.count
  end

  def total_hours_logged
    active_projects.sum(&:total_hours_logged)
  end

  def latest_activity_at
    timestamps = active_projects.map(&:latest_activity_at).compact
    timestamps.max
  end

  def latest_activity_sort_key
    keys = active_projects.filter_map do |project|
      entry = project.latest_time_entry
      next unless entry

      [entry.date, entry.created_at]
    end

    keys.max
  end
end
