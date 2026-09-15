class PennylaneInvoice < ApplicationRecord
  has_many :project_pennylane_invoices, dependent: :destroy
  has_many :projects, through: :project_pennylane_invoices

  validates :remote_id, presence: true, uniqueness: true

  scope :recent_first, -> { order(created_at: :desc) }

  def self.cache_from_remote!(invoice)
    record = find_or_initialize_by(remote_id: invoice.id)
    record.update!(
      number: invoice.number.presence,
      last_synced_at: Time.current
    )
    record
  end

  def display_number
    number.presence || remote_id
  end
end
