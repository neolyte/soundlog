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

      if persisted_record?(project_client)
        items << ["Clients", clients_path]
        items << [project_client.name, client_path(project_client)]
        items << ["Projects", client_projects_path(project_client)] if action_name == "index"
        items << ["New Project", new_client_project_path(project_client)] if action_name == "new"
      else
        items << ["Projects", projects_path]
      end

      items << [@project.name, project_path(@project)] if persisted_record?(@project) && action_name.in?(%w[show edit])
      items << ["Edit", edit_project_path(@project)] if persisted_record?(@project) && action_name == "edit"
    when "time_entries"
      items << ["Time Entries", time_entries_path]
      items << [@time_entry.project.name, time_entry_path(@time_entry)] if persisted_record?(@time_entry) && action_name.in?(%w[show edit])
      items << ["New Entry", new_time_entry_path] if action_name == "new"
      items << ["Edit", edit_time_entry_path(@time_entry)] if persisted_record?(@time_entry) && action_name == "edit"
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
    clock_hours = total_minutes / 60
    minutes = total_minutes % 60

    "#{clock_hours}:#{minutes.to_s.rjust(2, "0")}"
  end

  def project_accent_colors(project)
    key = [project&.name, project&.client&.name].join(":")
    PROJECT_ACCENT_PALETTE[Zlib.crc32(key) % PROJECT_ACCENT_PALETTE.length]
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
      projects: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M3 7h7l2 2h9v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><path d="M3 7V5a2 2 0 0 1 2-2h4l2 2"/></svg>',
      time_entries: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="8"/><path d="M12 7v5l3 2"/></svg>',
      clients: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="9.5" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
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
