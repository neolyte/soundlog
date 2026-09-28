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

    attr_reader :entries, :projects, :month

    def initialize(entries:, projects:, month:)
      @entries = entries
      @projects = projects
      @month = month.to_date.beginning_of_month
    end

    def invoiceable_open_entries
      @invoiceable_open_entries ||= entries.select { |entry| entry.status == "unbilled" && entry.invoiceable? }
    end

    def invoiceable_open_hours
      @invoiceable_open_hours ||= sum_hours(invoiceable_open_entries)
    end

    def invoiceable_open_amounts_by_currency
      @invoiceable_open_amounts_by_currency ||= invoiceable_open_entries.each_with_object(Hash.new { |hash, key| hash[key] = BigDecimal("0") }) do |entry, totals|
        next unless entry.invoiceable_amount.present?

        totals[entry.project.hourly_rate_currency] += entry.invoiceable_amount
      end
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

    def non_retainer_included_maintenance_hours
      @non_retainer_included_maintenance_hours ||= sum_hours(non_retainer_included_maintenance_entries)
    end

    def quoted_fixed_hours
      @quoted_fixed_hours ||= sum_hours(entries.select(&:quoted_fixed?))
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

    private

    def maintenance_projects
      @maintenance_projects ||= begin
        project_ids_with_usage = entries.select(&:included_maintenance?).map(&:project_id)

        projects.select do |project|
          project.included_maintenance? || project_ids_with_usage.include?(project.id)
        end
      end
    end

    def retainer_projects
      @retainer_projects ||= projects.select(&:monthly_retainer?)
    end

    def retainer_entries
      @retainer_entries ||= entries.select { |entry| entry.included_maintenance? && entry.project&.monthly_retainer? }
    end

    def non_retainer_included_maintenance_entries
      @non_retainer_included_maintenance_entries ||= entries.select { |entry| entry.included_maintenance? && !entry.project&.monthly_retainer? }
    end

    def sum_hours(collection)
      collection.sum { |entry| entry.hours || 0 }
    end
  end
end
