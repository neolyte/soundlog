require "zlib"

module ApplicationHelper
  PROJECT_ACCENT_PALETTE = [
    { strong: "#efb6a5", soft: "#fdf1ec" },
    { strong: "#d8a3d2", soft: "#f8edf7" },
    { strong: "#97ccc7", soft: "#ecf8f6" },
    { strong: "#c8db7d", soft: "#f7faeb" },
    { strong: "#f0c77f", soft: "#fdf6e7" },
    { strong: "#89b4e9", soft: "#edf4fd" },
    { strong: "#a7bf8f", soft: "#f1f6ed" },
    { strong: "#d8b48c", soft: "#fbf4ec" }
  ].freeze

  def breadcrumbs
    items = [["Dashboard", root_path]]

    case controller_name
    when "users"
      items << ["Users", users_path]
      items << ["New User", new_user_path] if action_name == "new"
      items << [@user.full_name, edit_user_path(@user)] if persisted_record?(@user) && action_name == "edit"
    when "clients"
      items << ["Clients", clients_path]
      items << [@client.name, client_path(@client)] if persisted_record?(@client) && action_name != "index"
      items << ["New", new_client_path] if action_name == "new"
      items << ["Edit", edit_client_path(@client)] if persisted_record?(@client) && action_name == "edit"
    when "projects"
      project_client =
        if defined?(@client) && @client.present?
          @client
        elsif defined?(@project) && @project.present?
          @project.client
        end

      if project_navigation_from_projects?
        items << ["Projects", projects_path]
      elsif persisted_record?(project_client)
        items << ["Clients", clients_path]
        items << [project_client.name, client_path(project_client)]
        items << ["Projects", client_projects_path(project_client)] if action_name == "index"
        items << ["New Project", new_client_project_path(project_client)] if action_name == "new"
      else
        items << ["Projects", projects_path]
      end

      items << [@project.name, project_path(@project, project_navigation_params)] if persisted_record?(@project) && action_name.in?(%w[show edit])
      items << ["Edit", edit_project_path(@project, project_navigation_params)] if persisted_record?(@project) && action_name == "edit"
    when "project_retainer_periods"
      items << ["Projects", projects_path]
      items << [@project.name, project_path(@project, project_navigation_params)] if persisted_record?(@project)
      items << ["Monthly Included Overrides", project_retainer_periods_path(@project, project_navigation_params)] if persisted_record?(@project)
    when "project_pennylane_invoices"
      items << ["Projects", projects_path]
      items << [@project.name, project_path(@project, project_navigation_params)] if persisted_record?(@project)
      items << ["Invoices", project_pennylane_invoices_path(@project)] if persisted_record?(@project)
    when "time_entries"
      items << ["Time Entries", time_entries_path]
      items << [@time_entry.project.name, time_entry_path(@time_entry)] if persisted_record?(@time_entry) && action_name.in?(%w[show edit])
      items << ["New Entry", new_time_entry_path] if action_name == "new"
      items << ["Edit", edit_time_entry_path(@time_entry)] if persisted_record?(@time_entry) && action_name == "edit"
    when "billing_reports"
      items << ["Billing", billing_path(month: @billing_summary_month&.strftime("%Y-%m"))]
      if action_name == "show" && @billing_category.present?
        items << [
          @billing_category_label,
          billing_category_detail_path(@billing_category, @billing_summary_month)
        ]
      end
    when "accounts"
      items << ["Account", edit_account_path]
    end

    items
  end

  def persisted_record?(record)
    record.present? && record.respond_to?(:persisted?) && record.persisted?
  end

  def format_date(date)
    date&.strftime("%B %d, %Y")
  end

  def format_month(date)
    date&.strftime("%B %Y")
  end

  def format_hours(hours)
    number_with_precision(hours, precision: 2)
  end

  def format_hours_as_clock(hours)
    total_minutes = (hours.to_f * 60).round
    sign = total_minutes.negative? ? "-" : ""
    absolute_minutes = total_minutes.abs
    clock_hours = absolute_minutes / 60
    minutes = absolute_minutes % 60

    "#{sign}#{clock_hours}:#{minutes.to_s.rjust(2, "0")}"
  end

  def format_hours_as_clock_with_unit(hours)
    "#{format_hours_as_clock(hours)} h"
  end

  def format_hours_ratio_as_clock_with_unit(hours, total_hours)
    "#{format_hours_as_clock(hours)} / #{format_hours_as_clock(total_hours)} h"
  end

  def project_budget_progress(project, retainer_month:)
    if project.fixed_budget?
      logged_hours = project.total_hours_logged
      budget_hours = project.total_hours
      logged_label = logged_hours.to_f.round
      budget_label = "#{budget_hours.to_f.round} hours"
    elsif project.monthly_retainer?
      logged_hours = project.total_hours_logged_between(retainer_month.all_month)
      budget_hours = project.monthly_retainer_hours_for(retainer_month)
      logged_label = logged_hours.to_f.round
      budget_label = "#{budget_hours.to_f.round} hours"
    else
      return
    end

    {
      budget_hours:,
      budget_label:,
      logged_hours:,
      logged_label:,
      over_budget: logged_hours > budget_hours,
      progress_percent: budget_hours.to_f.positive? ? [(logged_hours.to_f / budget_hours.to_f) * 100, 100].min : 0
    }
  end

  def project_logged_hours_label(hours)
    "#{hours.to_f.round} hours"
  end

  def time_entry_status_label(entry)
    case entry.status
    when "billed"
      "billed"
    when "unbilled"
      "unbilled"
    else
      "non-billable"
    end
  end

  def time_entry_status_class(entry)
    normalized_status = entry.status.presence || "non-billable"
    "time-entry-ledger__status--#{normalized_status}"
  end

  def project_billing_treatment_options
    Project::BILLING_TREATMENT_LABELS.map { |value, label| [label, value] }
  end

  def time_entry_billing_treatment_options(project = nil)
    default_label = "Use project default"
    default_label = "#{default_label} (#{project.billing_treatment_label})" if project.present?

    [[default_label, ""]] + project_billing_treatment_options
  end

  def time_entry_billing_treatment_label(entry)
    entry.effective_billing_treatment_label
  end

  def billing_treatment_class(treatment)
    "billing-treatment--#{treatment.presence || Project::DEFAULT_BILLING_TREATMENT}"
  end

  def project_monthly_billing_summary_item(project, billing_summary, month)
    case project.billing_treatment
    when "retainer"
      included_hours = project.monthly_retainer_hours_for(month)
      details = [
        if included_hours.present?
          format_hours_ratio_as_clock_with_unit(billing_summary.retainer_hours, included_hours)
        else
          format_hours_as_clock_with_unit(billing_summary.retainer_hours)
        end
      ]

      {
        label: "Retainer",
        value: format_money_totals(billing_summary.retainer_amounts_by_currency, empty_label: "-"),
        details: details
      }
    when "included_maintenance"
      {
        label: "Included maintenance",
        value: format_money_totals(billing_summary.included_maintenance_amounts_by_currency, empty_label: "-"),
        details: [format_hours_as_clock_with_unit(billing_summary.included_maintenance_hours)]
      }
    when "quoted_fixed"
      {
        label: "Quoted/fixed",
        value: format_money_totals(billing_summary.quoted_fixed_billed_amounts_by_currency, empty_label: "-"),
        details: [format_hours_as_clock_with_unit(billing_summary.quoted_fixed_hours)]
      }
    when "not_charged"
      {
        label: "No charge",
        value: format_hours_as_clock_with_unit(billing_summary.not_charged_hours),
        details: []
      }
    else
      {
        label: "Invoiceable",
        value: (
          if billing_summary.invoiceable_hours.positive?
            format_money_totals(billing_summary.invoiceable_amounts_by_currency, empty_label: "-")
          else
            "-"
          end
        ),
        details: [format_hours_as_clock_with_unit(billing_summary.invoiceable_hours)]
      }
    end
  end

  def billing_category_detail_path(category, month)
    billing_category_path(category, month: month.strftime("%Y-%m"))
  end

  def billing_category_time_entries_params(category, month, project = nil)
    {
      start_date: month.to_s,
      end_date: month.end_of_month.to_s,
      billing_category: category,
      project_id: project&.id
    }.compact
  end

  def billing_breakdown_row_projects(row)
    Array(row.projects.presence || row.project).compact
  end

  def format_money_amount(amount, currency)
    case currency.to_s.upcase
    when "EUR"
      number_to_currency(amount, unit: " €", precision: 2, format: "%n%u")
    when "USD"
      number_to_currency(amount, unit: "$", precision: 2, format: "%u%n")
    else
      number_to_currency(amount, unit: "#{currency} ", precision: 2, format: "%u%n")
    end
  end

  def format_eur_amount(amount)
    number_to_currency(amount, unit: " €", precision: 0, format: "%n%u")
  end

  def currency_symbol(currency)
    case currency.to_s.upcase
    when "EUR"
      "€"
    when "USD"
      "$"
    else
      currency
    end
  end

  def format_dashboard_eur_total(totals_by_currency, empty_label: "No rate set")
    totals = totals_by_currency.reject { |_currency, amount| amount.blank? || amount.to_d.zero? }
    return empty_label if totals.empty?

    estimated_total = estimated_eur_total(totals)
    return "Set EUR/USD rate" if estimated_total.blank? && CurrencyEstimate.relevant?(totals)

    format_eur_amount(estimated_total)
  end

  def dashboard_billing_total_amounts_by_currency(billing_summary)
    billing_summary.revenue_amounts_by_currency
  end

  def format_money_amount_with_estimated_eur(amount, currency)
    formatted_amount = format_money_amount(amount, currency)
    return formatted_amount unless currency.to_s.upcase == CurrencyEstimate::SOURCE_CURRENCY

    estimated_amount = estimated_eur_total(currency => amount)
    return formatted_amount unless estimated_amount.present?

    safe_join(
      [
        formatted_amount,
        content_tag(
          :small,
          "(#{estimated_eur_amount_label(estimated_amount)})",
          class: "money-estimate money-estimate--inline"
        )
      ],
      " "
    )
  end

  def format_money_totals(totals_by_currency, empty_label: "No rate set", include_estimated_eur: true)
    totals = totals_by_currency.reject { |_currency, amount| amount.to_d.zero? }
    return empty_label if totals.empty?

    lines = totals.sort.map do |currency, amount|
      if include_estimated_eur
        format_money_amount_with_estimated_eur(amount, currency)
      else
        format_money_amount(amount, currency)
      end
    end
    if include_estimated_eur && CurrencyEstimate.relevant?(totals) && estimated_eur_total(totals).blank?
      lines << estimated_eur_totals_line(totals)
    end

    safe_join(lines, tag.br)
  end

  def estimated_eur_total(totals_by_currency)
    CurrencyEstimate.eur_total(totals_by_currency)
  end

  def estimated_eur_amount_label(amount)
    "Est. #{format_eur_amount(amount)}"
  end

  def estimated_eur_totals_line(totals_by_currency)
    estimated_total = estimated_eur_total(totals_by_currency)

    if estimated_total.present?
      estimated_eur_amount_label(estimated_total)
    else
      "Set EUR/USD rate for EUR estimate"
    end
  end

  def eur_exchange_rate_label
    CurrencyEstimate.rate_label
  end

  def hidden_fields_tags(fields)
    safe_join(
      fields.filter_map do |name, value|
        next if value.blank?

        hidden_field_tag(name, value)
      end
    )
  end

  def project_accent_colors(project)
    if project&.color.present?
      return { strong: project.color, soft: hex_color_with_alpha(project.color, 0.12) }
    end

    key = [project&.name, project&.client&.name].join(":")
    PROJECT_ACCENT_PALETTE[Zlib.crc32(key) % PROJECT_ACCENT_PALETTE.length]
  end

  def client_accent_colors(client)
    key = [client&.name, client&.user&.full_name].join(":")
    PROJECT_ACCENT_PALETTE[Zlib.crc32(key) % PROJECT_ACCENT_PALETTE.length]
  end

  def hex_color_with_alpha(color, alpha)
    hex = color.delete_prefix("#")
    red = hex[0, 2].to_i(16)
    green = hex[2, 2].to_i(16)
    blue = hex[4, 2].to_i(16)

    "rgba(#{red}, #{green}, #{blue}, #{alpha})"
  end

  def project_navigation_from_projects?
    params[:source] == "projects"
  end

  def project_navigation_params
    project_navigation_from_projects? ? { source: "projects" } : {}
  end

  def sidebar_nav_link(label, path, icon)
    classes = ["sidebar-nav__link"]
    classes << "is-active" if current_page?(path)

    link_to path, class: classes.join(" ") do
      safe_join(
        [
          content_tag(:span, nav_icon(icon), class: "sidebar-nav__icon"),
          content_tag(:span, label, class: "sidebar-nav__label")
        ]
      )
    end
  end

  def nav_icon(icon)
    icons = {
      dashboard: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="4" rx="1.5"/><rect x="14" y="10" width="7" height="11" rx="1.5"/><rect x="3" y="13" width="7" height="8" rx="1.5"/></svg>',
      users: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="8.5" cy="7" r="4"/><path d="M20 8v6"/><path d="M17 11h6"/></svg>',
      projects: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7h7l2 2h9v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M3 7V5a2 2 0 0 1 2-2h4l2 2"/></svg>',
      time_entries: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/></svg>',
      clients: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="9.5" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
      billing: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19h16"/><path d="M7 16V9"/><path d="M12 16V5"/><path d="M17 16v-4"/></svg>',
      account: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M4 21a8 8 0 0 1 16 0"/><path d="M19 7h2"/><path d="M20 6v2"/></svg>',
      logout: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="M16 17l5-5-5-5"/><path d="M21 12H9"/></svg>'
    }

    icons.fetch(icon).html_safe
  end

  def month_nav_links(current_month)
    prev_month = current_month - 1.month
    next_month = current_month + 1.month
    
    html = "<div style='display: flex; gap: 1rem; align-items: center;'>"
    html += "<a href='/time_entries?month=#{prev_month.strftime('%Y-%m')}' class='btn secondary'>← Previous</a>"
    html += "<span>#{format_month(current_month)}</span>"
    html += "<a href='/time_entries?month=#{next_month.strftime('%Y-%m')}' class='btn secondary'>Next →</a>"
    html += "</div>"
    
    html.html_safe
  end
end
