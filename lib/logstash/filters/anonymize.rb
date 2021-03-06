require "logstash/filters/base"
require "logstash/namespace"

# Anonymize fields using by replacing values with a consistent hash.
class LogStash::Filters::Anonymize < LogStash::Filters::Base
  config_name "anonymize"
  milestone 1

  # The fields to be anonymized
  config :fields, :validate => :array, :required => true

  # Hashing key
  # When using MURMUR3 the key is ignored but must still be set.
  # When using IPV4_NETWORK key is the subnet prefix lentgh
  config :key, :validate => :string, :required => true

  # digest/hash type
  config :algorithm, :validate => ['SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5', "MURMUR3", "IPV4_NETWORK"], :required => true, :default => 'SHA1'

  public
  def register
    # require any library and set the anonymize function
    case @algorithm
    when "IPV4_NETWORK"
      require 'ipaddr'
      class << self; alias_method :anonymize, :anonymize_ipv4_network; end
    when "MURMUR3"
      require "murmurhash3"
      class << self; alias_method :anonymize, :anonymize_murmur3; end
    else
      require 'openssl'
      class << self; alias_method :anonymize, :anonymize_openssl; end
    end
  end # def register

  public
  def filter(event)
    return unless filter?(event)
    @fields.each do |field|
      next unless event.include?(field)
      if event[field].is_a?(Array)
        event[field] = event[field].collect { |v| anonymize(v) }
      else
        event[field] = anonymize(event[field])
      end
    end
  end # def filter

  private
  def anonymize_ipv4_network(ip_string)
    IPAddr.new(ip_string).mask(@key.to_i).to_s
  end  

  def anonymize_openssl(data)
    digest = algorithm()
    OpenSSL::HMAC.hexdigest(digest, @key, data)
  end

  def anonymize_murmur3(value)
    case value
    when Fixnum
      MurmurHash3::V32.int_hash(value)
    when String
      MurmurHash3::V32.str_hash(value)
    end
  end

  def algorithm
 
   case @algorithm
      #when 'SHA'
        #return OpenSSL::Digest::SHA.new
      when 'SHA1'
        return OpenSSL::Digest::SHA1.new
      #when 'SHA224'
        #return OpenSSL::Digest::SHA224.new
      when 'SHA256'
        return OpenSSL::Digest::SHA256.new
      when 'SHA384'
        return OpenSSL::Digest::SHA384.new
      when 'SHA512'
        return OpenSSL::Digest::SHA512.new
      #when 'MD4'
        #return OpenSSL::Digest::MD4.new
      when 'MD5'
        return OpenSSL::Digest::MD5.new
      else
        @logger.error("Unknown algorithm")
    end
  end
      
end # class LogStash::Filters::Anonymize
