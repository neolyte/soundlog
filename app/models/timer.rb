class Timer < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true

  enum :state, { running: "running", paused: "paused" }, default: :running, validate: true

  validates :user_id, presence: true, uniqueness: true
  validates :accumulated_seconds, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :started_at, presence: true, if: :running?

  def elapsed_seconds(reference_time = Time.current)
    return accumulated_seconds if paused? || started_at.blank?

    accumulated_seconds + (reference_time - started_at).to_i
  end

  def pause!(reference_time = Time.current)
    return if paused?

    update!(
      accumulated_seconds: elapsed_seconds(reference_time),
      started_at: nil,
      state: :paused
    )
  end

  def resume!(reference_time = Time.current)
    return if running?

    update!(started_at: reference_time, state: :running)
  end

  def loggable?
    project.present? && elapsed_seconds.positive?
  end

  def build_time_entry
    hours = (elapsed_seconds / 3600.0).round(2)
    hours = 0.01 if hours.zero? && elapsed_seconds.positive?

    user.time_entries.build(
      project:,
      date: Time.zone.today,
      hours:,
      description:
    )
  end
end
