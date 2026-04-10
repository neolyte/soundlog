class User < ApplicationRecord
  has_secure_password

  has_many :clients, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :time_entries, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :password, presence: true, length: { minimum: 6 }, if: -> { new_record? || changes[:password_digest] }

  def self.authenticate(email, password)
    user = find_by(email:)
    user&.authenticate(password)
  end
end
