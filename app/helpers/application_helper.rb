module ApplicationHelper
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
