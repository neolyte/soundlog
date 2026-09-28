class TimeEntry < ApplicationRecord
  BILLABLE_STATUSES = %w[unbilled billed].freeze
  EFFECTIVE_BILLING_TREATMENT_SQL = "COALESCE(NULLIF(time_entries.billing_treatment, ''), projects.billing_treatment)".freeze

  belongs_to :user
  belongs_to :project

  validates :user_id, presence: true
  validates :project_id, presence: true
  validates :date, presence: true
  validates :hours, presence: true, numericality: { greater_than: 0 }
  validates :billing_treatment, inclusion: { in: Project::BILLING_TREATMENTS }, allow_blank: true
  validate :project_must_be_loggable
  before_validation :normalize_billing_treatment

  scope :for_user, ->(user, view_all = user.admin?) { view_all ? all : where(user_id: user.id) }
  scope :for_month, ->(date) { where(date: date.beginning_of_month..date.end_of_month) }
  scope :ordered, -> { order(date: :desc, created_at: :desc) }
  scope :for_billing_category, lambda { |category|
    joined_scope = joins(:project)

    case category.to_s
    when "retainer"
      joined_scope
        .where(status: BILLABLE_STATUSES)
        .where.not(projects: { monthly_retainer_hours: nil })
        .where("#{EFFECTIVE_BILLING_TREATMENT_SQL} = ?", "included_maintenance")
    when "included_maintenance"
      joined_scope
        .where(status: BILLABLE_STATUSES)
        .where(projects: { monthly_retainer_hours: nil })
        .where("#{EFFECTIVE_BILLING_TREATMENT_SQL} = ?", "included_maintenance")
    when "invoiceable", "quoted_fixed"
      joined_scope
        .where(status: BILLABLE_STATUSES)
        .where("#{EFFECTIVE_BILLING_TREATMENT_SQL} = ?", category.to_s)
    when "not_charged"
      joined_scope.where(
        "time_entries.status IS NULL OR time_entries.status NOT IN (:billable_statuses) OR (time_entries.status IN (:billable_statuses) AND #{EFFECTIVE_BILLING_TREATMENT_SQL} = :treatment)",
        billable_statuses: BILLABLE_STATUSES,
        treatment: "not_charged"
      )
    else
      all
    end
  }

  def total_hours_for_date
    TimeEntry.where(user_id:, date:).sum(:hours)
  end

  def billable?
    BILLABLE_STATUSES.include?(status)
  end

  def billed?
    status == "billed"
  end

  def billing_treatment_override?
    billing_treatment.present?
  end

  def effective_billing_treatment
    return "not_charged" unless billable?

    billing_treatment.presence || project&.billing_treatment || Project::DEFAULT_BILLING_TREATMENT
  end

  def effective_billing_treatment_label
    Project::BILLING_TREATMENT_LABELS.fetch(effective_billing_treatment, effective_billing_treatment.to_s.humanize)
  end

  def invoiceable?
    effective_billing_treatment == "invoiceable"
  end

  def included_maintenance?
    effective_billing_treatment == "included_maintenance"
  end

  def quoted_fixed?
    effective_billing_treatment == "quoted_fixed"
  end

  def not_charged?
    effective_billing_treatment == "not_charged"
  end

  def invoiceable_amount
    return unless invoiceable?
    return unless project&.hourly_rate?

    hours * project.hourly_rate
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

  def normalize_billing_treatment
    self.billing_treatment = billing_treatment.presence
  end

  def project_must_be_loggable
    return if project.blank?
    return unless project.archived?

    errors.add(:project, "must be active")
  end
end
