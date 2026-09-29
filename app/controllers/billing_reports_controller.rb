class BillingReportsController < ApplicationController
  include BillingSummaryContext

  def index
    @billing_summary_month = selected_billing_month
    @billing_summary = billing_summary_for(@billing_summary_month)
    @revenue_share_charts = billing_revenue_share_charts(@billing_summary)
  end
end
