class ExchangeRate < ApplicationRecord
  CURRENCY_CODE_FORMAT = /\A[A-Z]{3}\z/

  before_validation :normalize_currency_codes

  validates :base_currency, presence: true, format: { with: CURRENCY_CODE_FORMAT }
  validates :quote_currency, presence: true, format: { with: CURRENCY_CODE_FORMAT }
  validates :rate, presence: true, numericality: { greater_than: 0 }
  validates :observed_on, presence: true
  validates :observed_on, uniqueness: { scope: [:base_currency, :quote_currency] }

  scope :for_pair, lambda { |base_currency, quote_currency|
    where(
      base_currency: normalize_currency_code(base_currency),
      quote_currency: normalize_currency_code(quote_currency)
    )
  }
  scope :recent_first, -> { order(observed_on: :desc, updated_at: :desc, id: :desc) }

  def self.latest_for(base_currency, quote_currency)
    for_pair(base_currency, quote_currency).recent_first.first
  end

  def self.normalize_currency_code(value)
    value.to_s.strip.upcase
  end

  private

  def normalize_currency_codes
    self.base_currency = ExchangeRate.normalize_currency_code(base_currency)
    self.quote_currency = ExchangeRate.normalize_currency_code(quote_currency)
  end
end
