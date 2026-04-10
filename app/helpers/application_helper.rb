module ApplicationHelper
  def breadcrumbs
    items = [["Dashboard", root_path]]

    case controller_name
    when "clients"
      items << ["Clients", clients_path]
      items << [@client.name, client_path(@client)] if defined?(@client) && @client.present? && action_name != "index"
      items << ["New", new_client_path] if action_name == "new"
      items << ["Edit", edit_client_path(@client)] if action_name == "edit" && defined?(@client) && @client.present?
    when "projects"
      project_client =
        if defined?(@client) && @client.present?
          @client
        elsif defined?(@project) && @project.present?
          @project.client
        end

      if project_client.present?
        items << ["Clients", clients_path]
        items << [project_client.name, client_path(project_client)]
        items << ["Projects", client_projects_path(project_client)] if action_name == "index"
        items << ["New Project", new_client_project_path(project_client)] if action_name == "new"
      else
        items << ["Projects", projects_path]
      end

      items << [@project.name, project_path(@project)] if defined?(@project) && @project.present? && action_name.in?(%w[show edit])
      items << ["Edit", edit_project_path(@project)] if action_name == "edit" && defined?(@project) && @project.present?
    when "time_entries"
      items << ["Time Entries", time_entries_path]
      items << [@time_entry.project.name, time_entry_path(@time_entry)] if defined?(@time_entry) && @time_entry.present? && action_name.in?(%w[show edit])
      items << ["New Entry", new_time_entry_path] if action_name == "new"
      items << ["Edit", edit_time_entry_path(@time_entry)] if action_name == "edit" && defined?(@time_entry) && @time_entry.present?
    end

    items
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
