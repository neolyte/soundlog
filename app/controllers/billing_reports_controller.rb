class BillingReportsController < ApplicationController
  include BillingSummaryContext
  BILLING_CATEGORY_LABELS = {
    "invoiceable" => "Invoiceable",
    "retainer" => "Retainer",
    "included_maintenance" => "Maintenance",
    "quoted_fixed" => "Quoted/fixed",
    "not_charged" => "No charge"
  }.freeze

  before_action :require_billing_reports_enabled

  def index
    @billing_summary_month = selected_billing_month
    @billing_summary = billing_summary_for(@billing_summary_month)
    @revenue_share_charts = billing_revenue_share_charts(@billing_summary)
  end

  def show
    @billing_category = normalized_billing_category(params[:category])

    unless @billing_category
      redirect_to billing_path(month: selected_billing_month.strftime("%Y-%m")), alert: "Unknown billing category"
      return
    end

    @billing_category_label = BILLING_CATEGORY_LABELS.fetch(@billing_category)
    @billing_summary_month = selected_billing_month
    @billing_summary = billing_summary_for(@billing_summary_month)
    @billing_breakdown_rows = @billing_summary.breakdown_rows(@billing_category)
    @billing_breakdown_amounts = @billing_summary.amounts_by_currency_for(@billing_category)
    @billing_breakdown_hours = @billing_summary.hours_for(@billing_category)
  end

  private

  def normalized_billing_category(value)
    category = value.to_s
    return category if BILLING_CATEGORY_LABELS.key?(category)

    nil
  end
end
