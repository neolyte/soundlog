class Project < ApplicationRecord
  SOLD_CURRENCIES = %w[EUR USD].freeze
  BILLING_TREATMENTS = %w[invoiceable included_maintenance quoted_fixed not_charged].freeze
  DEFAULT_BILLING_TREATMENT = "invoiceable"
  BILLING_TREATMENT_LABELS = {
    "invoiceable" => "Invoiceable",
    "included_maintenance" => "Included maintenance",
    "quoted_fixed" => "Quoted/fixed",
    "not_charged" => "No charge"
  }.freeze

  attribute :billable, :boolean, default: true
  attribute :billing_treatment, :string, default: DEFAULT_BILLING_TREATMENT

  belongs_to :user
  belongs_to :client
  has_many :time_entries, dependent: :destroy
  has_many :retainer_periods, class_name: "ProjectRetainerPeriod", dependent: :destroy
  has_many :project_pennylane_invoices, dependent: :destroy
  has_many :pennylane_invoices, through: :project_pennylane_invoices

  validates :name, presence: true
  validates :user_id, presence: true
  validates :client_id, presence: true
  validates :billable, inclusion: { in: [true, false] }
  validates :billing_treatment, inclusion: { in: BILLING_TREATMENTS }
  validates :total_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :monthly_retainer_hours, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :sold_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :sold_currency, inclusion: { in: SOLD_CURRENCIES }, allow_blank: true
  validates :hourly_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :hourly_rate_currency, inclusion: { in: SOLD_CURRENCIES }, allow_blank: true
  validates :color, format: { with: /\A#[0-9a-fA-F]{6}\z/ }, allow_blank: true
  validate :sold_amount_and_currency_are_paired
  validate :hourly_rate_and_currency_are_paired
  validate :sold_amount_only_for_non_retainer_projects
  validate :only_one_budget_value
  before_validation :normalize_sold_currency
  before_validation :normalize_hourly_rate_currency
  before_validation :normalize_billing_treatment
  before_validation :normalize_service_names

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

  def billing_treatment_label
    BILLING_TREATMENT_LABELS.fetch(billing_treatment, billing_treatment.to_s.humanize)
  end

  def invoiceable?
    billing_treatment == "invoiceable"
  end

  def included_maintenance?
    billing_treatment == "included_maintenance"
  end

  def quoted_fixed?
    billing_treatment == "quoted_fixed"
  end

  def not_charged?
    billing_treatment == "not_charged"
  end

  def hourly_rate?
    hourly_rate.present? && hourly_rate_currency.present?
  end

  def time_entries_billable_by_default?
    billable? || !not_charged?
  end

  def billing_summary_configured?
    hourly_rate? || sold_amount? || billing_treatment != DEFAULT_BILLING_TREATMENT
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

  def sold_amount?
    sold_amount.present?
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

  def billing_status
    pennylane_invoices.exists? ? "invoice_linked" : "not_invoiced"
  end

  def billing_status_label
    billing_status == "invoice_linked" ? "Invoice linked" : "No invoice linked"
  end

  def service_name_options
    service_names.to_s
      .lines
      .map(&:strip)
      .reject(&:blank?)
      .uniq
  end

  private

  def normalize_service_names
    self.service_names = service_name_options.join("\n").presence
  end

  def normalize_sold_currency
    self.sold_currency = sold_currency.to_s.upcase.presence
  end

  def normalize_hourly_rate_currency
    self.hourly_rate_currency = hourly_rate_currency.to_s.upcase.presence
  end

  def normalize_billing_treatment
    self.billing_treatment = billing_treatment.presence || DEFAULT_BILLING_TREATMENT
  end

  def only_one_budget_value
    return unless fixed_budget? && monthly_retainer?

    errors.add(:base, "Use total hours sold or monthly retainer hours, not both")
  end

  def sold_amount_and_currency_are_paired
    return if sold_amount.blank? && sold_currency.blank?

    errors.add(:sold_currency, "must be selected when sold amount is set") if sold_amount.present? && sold_currency.blank?
    errors.add(:sold_amount, "must be set when sold currency is selected") if sold_amount.blank? && sold_currency.present?
  end

  def hourly_rate_and_currency_are_paired
    return if hourly_rate.blank? && hourly_rate_currency.blank?

    errors.add(:hourly_rate_currency, "must be selected when hourly rate is set") if hourly_rate.present? && hourly_rate_currency.blank?
    errors.add(:hourly_rate, "must be set when hourly rate currency is selected") if hourly_rate.blank? && hourly_rate_currency.present?
  end

  def sold_amount_only_for_non_retainer_projects
    return unless monthly_retainer? && (sold_amount.present? || sold_currency.present?)

    errors.add(:sold_amount, "is only available for non-retainer projects")
  end
end
