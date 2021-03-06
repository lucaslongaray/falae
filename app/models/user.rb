class User < ApplicationRecord
  PHOTO_WIDTH = 400
  PHOTO_HEIGHT = 480
  VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  attr_accessor :activation_token, :reset_token, :crop_x, :crop_y, :crop_w, :crop_h

  has_one :role_user, dependent: :destroy
  has_one :role, through: :role_user
  has_many :spreadsheets, dependent: :destroy
  has_many :items
  has_attached_file :photo, default_url: 'missing_photo.png',
    path: "#{ENV['FALAE_IMAGES_PATH']}/private/user_:id/photo.:extension",
    url: '/users/:id/photo',
    styles: {crop: {resize_image: {width: PHOTO_WIDTH, height: PHOTO_HEIGHT}}},
    processors: [:cropper]

  before_create :create_activation_digest

  before_validation do
    if self.role.blank?
      self.role = Role.default
    end
  end

  before_save do
    self.email = email.downcase
  end

  before_destroy { self.photo = nil }

  after_update :reprocess_photo, if: :cropping?

  validates_associated :role
  validates :name, :last_name, presence: true, length: { maximum: 50 }
  validates :email, presence: true, uniqueness: { case_sensitive: false },
            length: { maximum: 255 }, format: { with: VALID_EMAIL_REGEX }
  validates :password, :password_confirmation, presence: true,
            length: { minimum: 6 }, on: :create
  validates_attachment_content_type :photo, content_type: /\Aimage\/(jpe?g|png|gif)\z/

  has_secure_password
  has_secure_token :auth_token

  def admin?
    false
  end

  def find_items_like_by(param)
    query = ["#{param.keys.first} LIKE ?", "#{param.values.first}%"]
    items.where(query)
  end

  # Returns hash digest of given string
  def User.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                  BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  # json token access
  def revalidate_token_access
    regenerate_auth_token
    touch(:auth_token_created_at)
  end

  def User.with_unexpired_auth_token(token, period)
    where(auth_token: token).where('auth_token_created_at >= ?', period).first
  end
  #

  # Returns random token
  def User.new_token
    SecureRandom.urlsafe_base64
  end

  # Returns true if given token matches digest
  def authentic_token?(attribute, token)
    digest = send("#{attribute}_digest")
    return false if digest.nil?
    BCrypt::Password.new(digest).is_password?(token)
  end

  # Activates user account
  def activate
    update_columns(activated: true, activated_at: Time.zone.now)
  end

  # Sends activation email
  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end

  # Sets the password reset attributes
  def create_reset_digest
    self.reset_token = User.new_token
    update_columns(reset_digest: User.digest(reset_token), reset_sent_at: Time.zone.now)
  end

  # Sends password reset email
  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end

  # Returns true if a password reset has expired.
  def password_reset_expired?
    self.reset_sent_at < 2.hours.ago
  end

  def cropping?
    crop_x.present? && crop_y.present? && crop_w.present? && crop_h.present?
  end

  private
    # Creates and assigns activation token and digest
    def create_activation_digest
      self.activation_token  = User.new_token
      self.activation_digest = User.digest(activation_token)
    end

    def reprocess_photo
      photo.reprocess!
    end
end
