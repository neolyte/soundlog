module Billing
  class MonthlySummary
    MaintenanceUsage = Struct.new(:project, :hours, :included_hours, keyword_init: true) do
      def included_hours?
        included_hours.present?
      end

      def remaining_hours
        return unless included_hours?

        included_hours - hours
      end

      def above_included?
        included_hours? && hours > included_hours
      end
    end
    BreakdownRow = Struct.new(
      :label,
      :sub_label,
      :project,
      :projects,
      :hours,
      :included_hours,
      :billable_hours,
      :overage_hours,
      :rate,
      :currency,
      :amount,
      :entries_count,
      :invoice,
      :note,
      keyword_init: true
    ) do
      def amount?
        amount.present? && currency.present?
      end

      def rate?
        rate.present? && currency.present?
      end
    end

    attr_reader :entries, :projects, :month

    def initialize(entries:, projects:, month:)
      @entries = entries
      @projects = projects
      @month = month.to_date.beginning_of_month
    end

    def invoiceable_open_entries
      @invoiceable_open_entries ||= entries.select { |entry| entry.status == "unbilled" && entry.invoiceable? }
    end

    def invoiceable_entries
      @invoiceable_entries ||= entries.select(&:invoiceable?)
    end

    def invoiceable_hours
      @invoiceable_hours ||= sum_hours(invoiceable_entries)
    end

    def invoiceable_amounts_by_currency
      @invoiceable_amounts_by_currency ||= sum_invoiceable_entry_amounts(invoiceable_entries)
    end

    def invoiceable_hours_without_rate
      @invoiceable_hours_without_rate ||= sum_hours(
        invoiceable_entries.reject { |entry| entry.project.hourly_rate? }
      )
    end

    def invoiceable_open_hours
      @invoiceable_open_hours ||= sum_hours(invoiceable_open_entries)
    end

    def invoiceable_open_amounts_by_currency
      @invoiceable_open_amounts_by_currency ||= sum_invoiceable_entry_amounts(invoiceable_open_entries)
    end

    def invoiceable_open_hours_without_rate
      @invoiceable_open_hours_without_rate ||= sum_hours(
        invoiceable_open_entries.reject { |entry| entry.project.hourly_rate? }
      )
    end

    def included_maintenance_hours
      @included_maintenance_hours ||= sum_hours(entries.select(&:included_maintenance?))
    end

    def included_maintenance_budget_hours
      @included_maintenance_budget_hours ||= maintenance_projects.filter_map { |project| project.monthly_retainer_hours_for(month) }.sum
    end

    def retainer_hours
      @retainer_hours ||= sum_hours(retainer_entries)
    end

    def retainer_budget_hours
      @retainer_budget_hours ||= retainer_projects.filter_map { |project| project.monthly_retainer_hours_for(month) }.sum
    end

    def retainer_overage_hours
      @retainer_overage_hours ||= retainer_projects.sum { |project| retainer_overage_hours_for(project) }
    end

    def retainer_overage_hours_without_rate
      @retainer_overage_hours_without_rate ||= retainer_projects.reject(&:hourly_rate?).sum { |project| retainer_overage_hours_for(project) }
    end

    def retainer_amounts_by_currency
      @retainer_amounts_by_currency ||= retainer_projects.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |project, totals|
        billable_hours = retainer_billable_hours_for(project)
        next unless billable_hours.positive? && project.hourly_rate?

        totals[project.hourly_rate_currency] += billable_hours * project.hourly_rate
      end
    end

    def non_retainer_included_maintenance_hours
      @non_retainer_included_maintenance_hours ||= included_maintenance_hours
    end

    def included_maintenance_amounts_by_currency
      @included_maintenance_amounts_by_currency ||= sum_project_amounts(projects.select(&:included_maintenance?))
    end

    def quoted_fixed_hours
      @quoted_fixed_hours ||= sum_hours(entries.select(&:quoted_fixed?))
    end

    def quoted_fixed_amounts_by_currency
      quoted_fixed_contract_amounts_by_currency
    end

    def quoted_fixed_contract_amounts_by_currency
      @quoted_fixed_contract_amounts_by_currency ||= sum_project_amounts(quoted_fixed_projects_with_usage)
    end

    def quoted_fixed_billed_amounts_by_currency
      @quoted_fixed_billed_amounts_by_currency ||= sum_invoice_amounts(quoted_fixed_projects_for_billing)
    end

    def revenue_amounts_by_currency
      @revenue_amounts_by_currency ||= sum_amount_totals(
        invoiceable_amounts_by_currency,
        retainer_amounts_by_currency,
        quoted_fixed_billed_amounts_by_currency,
        included_maintenance_amounts_by_currency
      )
    end

    def not_charged_hours
      @not_charged_hours ||= sum_hours(entries.select(&:not_charged?))
    end

    def configured?
      projects.any? { |project| project.billing_summary_configured? } || entries.any?(&:billing_treatment_override?)
    end

    def maintenance_usages
      @maintenance_usages ||= begin
        hours_by_project_id = entries.select(&:included_maintenance?).each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |entry, totals|
          totals[entry.project_id] += entry.hours
        end

        maintenance_projects.map do |project|
          MaintenanceUsage.new(
            project:,
            hours: hours_by_project_id[project.id],
            included_hours: project.monthly_retainer_hours_for(month)
          )
        end.sort_by { |usage| [usage.above_included? ? 0 : 1, -usage.hours.to_f, usage.project.name.downcase] }
      end
    end

    def breakdown_rows(category)
      case category.to_s
      when "invoiceable"
        invoiceable_breakdown_rows
      when "retainer"
        retainer_breakdown_rows
      when "included_maintenance"
        included_maintenance_breakdown_rows
      when "quoted_fixed"
        quoted_fixed_breakdown_rows
      when "not_charged"
        not_charged_breakdown_rows
      else
        []
      end
    end

    def amounts_by_currency_for(category)
      case category.to_s
      when "invoiceable"
        invoiceable_amounts_by_currency
      when "retainer"
        retainer_amounts_by_currency
      when "included_maintenance"
        included_maintenance_amounts_by_currency
      when "quoted_fixed"
        quoted_fixed_billed_amounts_by_currency
      else
        {}
      end
    end

    def hours_for(category)
      case category.to_s
      when "invoiceable"
        invoiceable_hours
      when "retainer"
        retainer_hours
      when "included_maintenance"
        included_maintenance_hours
      when "quoted_fixed"
        quoted_fixed_hours
      when "not_charged"
        not_charged_hours
      else
        BigDecimal("0")
      end
    end

    private

    def invoiceable_breakdown_rows
      project_entry_groups(invoiceable_entries).map do |project, project_entries|
        hours = sum_hours(project_entries)

        BreakdownRow.new(
          label: project.name,
          sub_label: project.client.name,
          project:,
          hours:,
          billable_hours: hours,
          rate: project.hourly_rate,
          currency: project.hourly_rate_currency,
          amount: (hours * project.hourly_rate if project.hourly_rate?),
          entries_count: project_entries.size,
          note: ("No hourly rate set" unless project.hourly_rate?)
        )
      end.sort_by { |row| project_sort_key(row.project) }
    end

    def retainer_breakdown_rows
      retainer_projects.map do |project|
        hours = retainer_hours_by_project_id[project.id]
        included_hours = project.monthly_retainer_hours_for(month)
        billable_hours = retainer_billable_hours_for(project)
        overage_hours = retainer_overage_hours_for(project)

        BreakdownRow.new(
          label: project.name,
          sub_label: project.client.name,
          project:,
          hours:,
          included_hours:,
          billable_hours:,
          overage_hours:,
          rate: project.hourly_rate,
          currency: project.hourly_rate_currency,
          amount: (billable_hours * project.hourly_rate if billable_hours.positive? && project.hourly_rate?),
          entries_count: retainer_entries.count { |entry| entry.project_id == project.id },
          note: retainer_breakdown_note(project, hours, included_hours, overage_hours)
        )
      end.sort_by { |row| project_sort_key(row.project) }
    end

    def included_maintenance_breakdown_rows
      hours_by_project_id = hours_by_project_id_for(entries.select(&:included_maintenance?))
      entries_count_by_project_id = entries_count_by_project_id_for(entries.select(&:included_maintenance?))

      maintenance_projects.map do |project|
        amount = project.sold_amount if project.included_maintenance? && project.sold_amount? && project.sold_currency.present?

        BreakdownRow.new(
          label: project.name,
          sub_label: project.client.name,
          project:,
          hours: hours_by_project_id[project.id],
          currency: project.sold_currency,
          amount:,
          entries_count: entries_count_by_project_id[project.id],
          note: included_maintenance_breakdown_note(project)
        )
      end.sort_by { |row| project_sort_key(row.project) }
    end

    def quoted_fixed_breakdown_rows
      rows = quoted_fixed_invoice_breakdown_rows
      rows + quoted_fixed_uninvoiced_breakdown_rows(rows)
    end

    def not_charged_breakdown_rows
      project_entry_groups(entries.select(&:not_charged?)).map do |project, project_entries|
        BreakdownRow.new(
          label: project.name,
          sub_label: project.client.name,
          project:,
          hours: sum_hours(project_entries),
          entries_count: project_entries.size
        )
      end.sort_by { |row| project_sort_key(row.project) }
    end

    def maintenance_projects
      @maintenance_projects ||= begin
        project_ids_with_usage = entries.select(&:included_maintenance?).map(&:project_id)

        projects.select do |project|
          project.included_maintenance? || project_ids_with_usage.include?(project.id)
        end
      end
    end

    def retainer_projects
      @retainer_projects ||= begin
        project_ids_with_usage = retainer_entries.map(&:project_id)

        projects.select do |project|
          project.retainer? || project_ids_with_usage.include?(project.id)
        end
      end
    end

    def retainer_entries
      @retainer_entries ||= entries.select(&:retainer?)
    end

    def retainer_hours_by_project_id
      @retainer_hours_by_project_id ||= retainer_entries.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |entry, totals|
        totals[entry.project_id] += entry.hours
      end
    end

    def retainer_overage_hours_for(project)
      overage_hours = retainer_hours_by_project_id[project.id] - (project.monthly_retainer_hours_for(month) || 0)
      overage_hours.positive? ? overage_hours : BigDecimal("0")
    end

    def retainer_billable_hours_for(project)
      included_hours = project.monthly_retainer_hours_for(month) || 0
      logged_hours = retainer_hours_by_project_id[project.id]

      logged_hours > included_hours ? logged_hours : included_hours
    end

    def sum_hours(collection)
      collection.sum { |entry| entry.hours || 0 }
    end

    def quoted_fixed_projects_with_usage
      @quoted_fixed_projects_with_usage ||= projects.select { |project| quoted_fixed_project_ids_with_usage.include?(project.id) }
    end

    def quoted_fixed_projects_for_billing
      @quoted_fixed_projects_for_billing ||= projects.select do |project|
        project.quoted_fixed? || quoted_fixed_project_ids_with_usage.include?(project.id)
      end
    end

    def quoted_fixed_project_ids_with_usage
      @quoted_fixed_project_ids_with_usage ||= entries.select(&:quoted_fixed?).map(&:project_id).uniq
    end

    def sum_project_amounts(projects)
      projects.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |project, totals|
        next unless project.sold_amount? && project.sold_currency.present?

        totals[project.sold_currency] += project.sold_amount
      end
    end

    def sum_invoiceable_entry_amounts(entries)
      entries.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |entry, totals|
        next unless entry.invoiceable_amount.present?

        totals[entry.project.hourly_rate_currency] += entry.invoiceable_amount
      end
    end

    def sum_amount_totals(*amount_totals)
      amount_totals.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |totals_by_currency, totals|
        totals_by_currency.each do |currency, amount|
          totals[currency] += amount
        end
      end
    end

    def sum_invoice_amounts(projects)
      seen_invoice_ids = {}

      projects.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |project, totals|
        project.pennylane_invoices.each do |invoice|
          next if seen_invoice_ids[invoice.id]
          next unless invoice.invoice_date.present? && month.all_month.cover?(invoice.invoice_date)
          next unless invoice.amount.present? && invoice.currency.present?

          seen_invoice_ids[invoice.id] = true
          totals[invoice.currency] += invoice.amount
        end
      end
    end

    def project_entry_groups(entries)
      entries
        .group_by(&:project)
        .sort_by { |project, _project_entries| project_sort_key(project) }
        .to_h
    end

    def hours_by_project_id_for(entries)
      entries.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |entry, totals|
        totals[entry.project_id] += entry.hours || 0
      end
    end

    def entries_count_by_project_id_for(entries)
      entries.each_with_object(Hash.new(0)) do |entry, totals|
        totals[entry.project_id] += 1
      end
    end

    def project_sort_key(project)
      [project.client.name.downcase, project.name.downcase]
    end

    def retainer_breakdown_note(project, hours, included_hours, overage_hours)
      return "No hourly rate set" unless project.hourly_rate?
      return "Over included hours" if overage_hours.positive?
      return "Monthly minimum" if included_hours.present? && included_hours.positive? && hours < included_hours

      nil
    end

    def included_maintenance_breakdown_note(project)
      if project.included_maintenance?
        "No monthly amount set" unless project.sold_amount? && project.sold_currency.present?
      else
        "Entry override; no monthly project amount"
      end
    end

    def quoted_fixed_invoice_breakdown_rows
      invoices_by_id = {}

      quoted_fixed_projects_for_billing.each do |project|
        project.pennylane_invoices.each do |invoice|
          next unless invoice.invoice_date.present? && month.all_month.cover?(invoice.invoice_date)
          next unless invoice.amount.present? && invoice.currency.present?

          invoice_details = invoices_by_id[invoice.id] ||= { invoice:, projects: [] }
          invoice_details[:projects] << project
        end
      end

      invoices_by_id.values.map do |invoice_details|
        invoice = invoice_details.fetch(:invoice)
        invoice_projects = invoice_details.fetch(:projects).uniq

        BreakdownRow.new(
          label: invoice.display_number,
          sub_label: invoice_projects.map { |project| "#{project.name} (#{project.client.name})" }.to_sentence,
          projects: invoice_projects,
          currency: invoice.currency,
          amount: invoice.amount,
          invoice:,
          note: "Invoice dated #{invoice.invoice_date.strftime('%d/%m/%Y')}"
        )
      end.sort_by { |row| [row.invoice.invoice_date, row.label] }
    end

    def quoted_fixed_uninvoiced_breakdown_rows(invoice_rows)
      invoiced_project_ids = invoice_rows.flat_map { |row| row.projects || [] }.map(&:id).uniq

      quoted_fixed_projects_for_billing.reject { |project| invoiced_project_ids.include?(project.id) }.map do |project|
        BreakdownRow.new(
          label: project.name,
          sub_label: project.client.name,
          project:,
          hours: sum_hours(entries.select { |entry| entry.quoted_fixed? && entry.project_id == project.id }),
          entries_count: entries.count { |entry| entry.quoted_fixed? && entry.project_id == project.id },
          note: "No linked invoice dated this month"
        )
      end.sort_by { |row| project_sort_key(row.project) }
    end
  end
end
