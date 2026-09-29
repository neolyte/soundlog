class PennylaneInvoice < ApplicationRecord
  has_many :project_pennylane_invoices, dependent: :destroy
  has_many :projects, through: :project_pennylane_invoices

  validates :remote_id, presence: true, uniqueness: true
  validates :amount, numericality: true, allow_nil: true
  validates :currency, length: { is: 3 }, allow_blank: true
  before_validation :normalize_currency

  scope :recent_first, -> { order(created_at: :desc) }

  def self.cache_from_remote!(invoice)
    record = find_or_initialize_by(remote_id: invoice.id)
    record.update!(
      number: invoice.number.presence,
      amount: invoice.amount,
      currency: invoice.currency.presence,
      invoice_date: invoice.date,
      last_synced_at: Time.current
    )
    record
  end

  def display_number
    number.presence || remote_id
  end

  private

  def normalize_currency
    self.currency = currency.to_s.upcase.presence
  end
end
