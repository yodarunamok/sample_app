# Set up the relevant port for the Riak client (for whatever reason, it doesn't yet use ripple.yml)
if Rails.env.production?
  RIAK_HTTP_PORT = 8098
elsif Rails.env.test?
  RIAK_HTTP_PORT = 9100
else
  RIAK_HTTP_PORT = 9000
end

class IsUniqueValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    if value.length > 0
      client = Riak::Client.new :solr => '/solr', :http_port => RIAK_HTTP_PORT
      result = client.search('users', "#{attribute.to_s}:#{value.downcase}")
      record.errors.add attribute, "must be unique" unless result['response']['numFound'] == 0
    end
  end
end

class User
  include Ripple::Document

  email_regex = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i

  timestamps!
  property 'name', :String, :presence => true, :length => { :maximum => 50 }
  property 'email', :String, :presence => true, :format => { :with => email_regex }, :is_unique => true

  def initialize(*args)
    client = Riak::Client.new :solr => '/solr', :http_port => RIAK_HTTP_PORT
    client['users'].enable_index! unless client['users'].is_indexed?
    super
  end

  def email=(value)
    @email = value.downcase!
    super
  end

end
