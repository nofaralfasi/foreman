class HttpURLValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)

    return if options[:allow_blank] && value.blank?

    if !valid_http_url?(value)
      record.errors.add(attribute, _("Invalid HTTP(S) URL"))
    end
  end

  private

  # Validates that a URL is a properly formatted HTTP or HTTPS URL
  # @param url [String] The URL to validate
  # @return [Boolean] true if the URL is valid HTTP(S)
  def valid_http_url?(url)

    return false unless url.is_a?(String) && url.present?
    
    begin
      uri = URI.parse(url)
      
      # Must be HTTP or HTTPS
      return false unless uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
      
      # Must have a host
      return false if uri.host.nil? || uri.host.empty?
      
      # Scheme must be properly formatted (not missing slashes)
      return false unless url.match?(/\Ahttps?:\/\//) 
      
      true
    rescue URI::InvalidURIError
      false
    end
  end
end
