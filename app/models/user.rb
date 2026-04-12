class User < ApplicationRecord
  has_secure_password

  has_many :clients, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :time_entries, dependent: :destroy
  has_one :timer, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, if: -> { new_record? || changes[:password_digest] }

  def self.authenticate(email, password)
    user = find_by(email:)
    user&.authenticate(password)
  end

  def full_name
    [first_name, last_name].join(" ")
  end
end
