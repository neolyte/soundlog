class AddAmountCurrencyAndInvoiceDateToPennylaneInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :pennylane_invoices, :amount, :decimal, precision: 12, scale: 2
    add_column :pennylane_invoices, :currency, :string
    add_column :pennylane_invoices, :invoice_date, :date
  end
end
