module BillingSummaryContext
  extend ActiveSupport::Concern

  REVENUE_SHARE_CATEGORIES = [
    { label: "Invoiceable", color: "#2563eb", amounts_method: :invoiceable_amounts_by_currency },
    { label: "Retainer", color: "#16a34a", amounts_method: :retainer_amounts_by_currency },
    { label: "Quoted/fixed", color: "#9333ea", amounts_method: :quoted_fixed_billed_amounts_by_currency },
    { label: "Maintenance", color: "#f97316", amounts_method: :included_maintenance_amounts_by_currency }
  ].freeze

  private

  def selected_billing_month(param_name = :month)
    parse_billing_month_param(params[param_name]) || Date.current.beginning_of_month
  end

  def billing_summary_for(month)
    Billing::MonthlySummary.new(
      entries: TimeEntry.for_user(current_user, admin_view_all?).for_month(month).includes(project: [:client, :retainer_periods]).to_a,
      projects: Project.for_user(current_user, admin_view_all?).active.includes(:client, :retainer_periods, :pennylane_invoices).to_a,
      month:
    )
  end

  def billing_revenue_share_charts(summary)
    charts_by_currency = Hash.new do |hash, currency|
      hash[currency] = {
        currency:,
        labels: [],
        values: [],
        colors: [],
        total: BigDecimal("0")
      }
    end

    REVENUE_SHARE_CATEGORIES.each do |category|
      summary.public_send(category.fetch(:amounts_method)).each do |currency, amount|
        next if amount.to_d.zero?

        chart = charts_by_currency[currency]
        chart[:labels] << category.fetch(:label)
        chart[:values] << amount.to_f
        chart[:colors] << category.fetch(:color)
        chart[:total] += amount
      end
    end

    charts_by_currency.values.sort_by { |chart| chart.fetch(:currency) }
  end

  def parse_billing_month_param(value)
    return if value.blank?

    Date.iso8601("#{value}-01").beginning_of_month
  rescue ArgumentError, Date::Error
    nil
  end
end
