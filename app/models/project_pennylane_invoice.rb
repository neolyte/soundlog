class ProjectPennylaneInvoice < ApplicationRecord
  belongs_to :project
  belongs_to :pennylane_invoice

  validates :pennylane_invoice_id, uniqueness: { scope: :project_id }
end
