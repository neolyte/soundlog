class ProjectRetainerPeriod < ApplicationRecord
  belongs_to :project

  before_validation :normalize_month

  validates :month, presence: true, uniqueness: { scope: :project_id }
  validates :retainer_hours, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :recent_first, -> { order(month: :desc) }

  private

  def normalize_month
    self.month = month.beginning_of_month if month.present?
  end
end
