class Project < ApplicationRecord
  attribute :billable, :boolean, default: true

  belongs_to :user
  belongs_to :client
  has_many :time_entries, dependent: :destroy
  has_many :retainer_periods, class_name: "ProjectRetainerPeriod", dependent: :destroy

  validates :name, presence: true
  validates :user_id, presence: true
  validates :client_id, presence: true
  validates :billable, inclusion: { in: [true, false] }
  validates :total_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :monthly_retainer_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validate :only_one_budget_value

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
  scope :ordered_by_retainer_first_recent_activity, lambda {
    left_joins(:time_entries)
      .group("projects.id")
      .order(
        Arel.sql("CASE WHEN projects.monthly_retainer_hours IS NULL THEN 1 ELSE 0 END ASC"),
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

  def total_hours_logged_between(date_range)
    if time_entries.loaded?
      time_entries.select { |entry| entry.date.present? && date_range.cover?(entry.date) }.sum(&:hours)
    else
      time_entries.where(date: date_range).sum(:hours)
    end
  end

  def unbilled_hours
    if time_entries.loaded?
      time_entries.select { |entry| entry.status == "unbilled" }.sum(&:hours)
    else
      time_entries.where(status: "unbilled").sum(:hours)
    end
  end

  def fixed_budget?
    total_hours.present?
  end

  def monthly_retainer?
    monthly_retainer_hours.present?
  end

  def retainer_period_for(month = Date.current)
    normalized_month = month.to_date.beginning_of_month

    if retainer_periods.loaded?
      retainer_periods.find { |period| period.month&.beginning_of_month == normalized_month }
    else
      retainer_periods.find_by(month: normalized_month)
    end
  end

  def monthly_retainer_hours_for(month = Date.current)
    return unless monthly_retainer?

    retainer_period_for(month)&.retainer_hours || monthly_retainer_hours
  end

  def budgeted?
    fixed_budget? || monthly_retainer?
  end

  def remaining_hours
    return unless fixed_budget?

    total_hours - total_hours_logged
  end

  def monthly_retainer_remaining_hours(month = Date.current)
    return unless monthly_retainer?

    monthly_retainer_hours_for(month) - total_hours_logged_between(month.all_month)
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

  private

  def only_one_budget_value
    return unless fixed_budget? && monthly_retainer?

    errors.add(:base, "Use total hours sold or monthly retainer hours, not both")
  end
end
