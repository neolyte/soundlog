class TimeEntry < ApplicationRecord
  BILLABLE_STATUSES = %w[unbilled billed].freeze

  belongs_to :user
  belongs_to :project

  validates :user_id, presence: true
  validates :project_id, presence: true
  validates :date, presence: true
  validates :hours, presence: true, numericality: { greater_than: 0 }
  validate :project_must_be_loggable

  scope :for_user, ->(user, view_all = user.admin?) { view_all ? all : where(user_id: user.id) }
  scope :for_month, ->(date) { where(date: date.beginning_of_month..date.end_of_month) }
  scope :ordered, -> { order(date: :desc, created_at: :desc) }

  def total_hours_for_date
    TimeEntry.where(user_id:, date:).sum(:hours)
  end

  def billable?
    BILLABLE_STATUSES.include?(status)
  end

  def billed?
    status == "billed"
  end

  def apply_billable_flag(value)
    self.status =
      if ActiveModel::Type::Boolean.new.cast(value)
        status == "billed" ? "billed" : "unbilled"
      else
        "non-billable"
      end
  end

  private

  def project_must_be_loggable
    return if project.blank?
    return unless project.archived?

    errors.add(:project, "must be active")
  end
end
