require 'digest'

class IsUniqueValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.strip.length > 0
      result = Ripple::client.search('users', "#{attribute.to_s}:#{value.downcase}")
      # Uniqueness can either be the result of a non-present value, or an update to the same record
      record.errors.add attribute, "must be unique" unless result['response']['numFound'] == 0 or
                                                          (result['response']['numFound'] == 1 and
                                                           result['response']['docs'][0]['id'] == record.key)
    end
  end
end

class User
  include Ripple::Document

  attr_accessor :password
  attr_accessible :name, :email, :password, :password_confirmation

  email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  timestamps!
  property 'name', :String, :presence => true, :length => { :maximum => 50 }
  property 'email', :String, :presence => true, :format => { :with => email_regex }, :is_unique => true
  property 'encrypted_password', :String
  property 'salt', :String
  # Automatically create the virtual attribute 'password_confirmation'.
  validates :password,  :presence => true,
                        :confirmation => true,
                        :length => { :within => 6..40 }

  before_save :encrypt_password

  # The only point of tweaking the constructor was to ensure that the necessary Riak Search index is present
  def initialize(*args)
    client = Ripple::client
    client['users'].enable_index! unless client['users'].is_indexed?
    super
  end

  # We add some normalization to the case of the user's email since we want emails to be unique and searchable
  def email=(value)
    @email = value.downcase!
    super
  end

  # Return true if the user's password matches the submitted password
  def has_password?(submitted_password)
    self.encrypted_password == encrypt(submitted_password)
  end

  # Begin Class methods
  class << self
    def authenticate(email, submitted_password)
      user = find_by_email(email)
      user && user.has_password?(submitted_password) ? user : nil
    end

    def authenticate_with_salt(id, cookie_salt)
      user = find(id)
      (user && user.salt == cookie_salt) ? user : nil
    end

    # Find and return a user by their email
    def find_by_email(email)
      if email.strip.length > 0
        result = Ripple::client.search('users', "email:#{email.downcase}")
        if result['response']['numFound'] == 1
          return User.find(result['response']['docs'][0]['id']) # is this the best way?
        end
      end
      nil # Returned if no conditions met (explicit to avoid IDE griping)
    end

    def stats
      # Returns a hash with keys: count, min, max, percentile25, median, percentile75, percentile99, mean, sum, variance, sdev
      client = Ripple::client
      Riak::MapReduce.new(client).add('users').map('Contrib.mapCount').reduce('Contrib.reduceStats', :keep => true).run
    end

    def count
      stats['count']
    end
  end
  # End Class methods

  # Begin Private methods
  private

    def encrypt_password
      self.salt = make_salt if new_record?
      self.encrypted_password = encrypt(self.password)
    end

    def encrypt(string)
      secure_hash("#{self.salt}--#{string}")
    end

    def make_salt
      secure_hash("#{Time.now.utc}--#{self.password}")
    end

    def secure_hash(string)
      Digest::SHA2.hexdigest(string)
    end
  # End Private methods

end
