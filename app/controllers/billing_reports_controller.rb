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
    @billing_breakdown_sort = billing_breakdown_sort_param
    @billing_breakdown_rows = sorted_billing_breakdown_rows(@billing_summary.breakdown_rows(@billing_category))
    @billing_breakdown_amounts = @billing_summary.amounts_by_currency_for(@billing_category)
    @billing_breakdown_hours = @billing_summary.hours_for(@billing_category)
  end

  private

  def normalized_billing_category(value)
    category = value.to_s
    return category if BILLING_CATEGORY_LABELS.key?(category)

    nil
  end

  def billing_breakdown_sort_param
    return "amount_asc" if params[:sort] == "amount_asc"
    return "amount_desc" if params[:sort] == "amount_desc"

    "default"
  end

  def sorted_billing_breakdown_rows(rows)
    case @billing_breakdown_sort
    when "amount_asc"
      rows
        .each_with_index
        .sort_by { |row, index| billing_breakdown_amount_sort_key(row, :asc, index) }
        .map(&:first)
    when "amount_desc"
      rows
        .each_with_index
        .sort_by { |row, index| billing_breakdown_amount_sort_key(row, :desc, index) }
        .map(&:first)
    else
      rows
    end
  end

  def billing_breakdown_amount_sort_key(row, direction, original_index)
    sortable_amount = billing_breakdown_sortable_amount(row)
    amount_sort_value = sortable_amount.present? ? sortable_amount.to_d : BigDecimal("0")
    amount_sort_value = -amount_sort_value if direction == :desc

    [sortable_amount.blank? ? 1 : 0, amount_sort_value, original_index]
  end

  def billing_breakdown_sortable_amount(row)
    return unless row.amount?

    case row.currency.to_s.upcase
    when CurrencyEstimate::TARGET_CURRENCY
      row.amount
    when CurrencyEstimate::SOURCE_CURRENCY
      CurrencyEstimate.eur_total(row.currency => row.amount) || row.amount
    else
      row.amount
    end
  end
end
