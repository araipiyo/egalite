require 'uri'
require 'net/http'
require 'net/https'

module Egalite
  module HTTP
    def self.parse_url(url, options)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
      if options[:continue_timeout]
        http.continue_timeout = options[:continue_timeout]
      end
      if options[:keep_alive_timeout]
        http.keep_alive_timeout = options[:keep_alive_timeout]
      end
      if options[:open_timeout]
        http.open_timeout = options[:open_timeout]
      end
      if options[:read_timeout]
        http.read_timeout = options[:read_timeout]
      end
      if options[:ssl_timeout]
        http.ssl_timeout = options[:ssl_timeout]
      end
      [http, uri]
    end
    def self.parse_options(options)
      if options[:basic_auth]
        u = options[:basic_auth][0]
        pw = options[:basic_auth][1]
        b = ["#{u}:#{pw}"].pack("m")
        options[:header] ||= {}
        options[:header]["Authorization"] = "Basic #{b}".chop
      end
    end
    def self.parse_response(response)
      ret = {}
      ret[:body] = response.body
      ret[:headers] = response.each {}
      ret[:headers] = Hash[ret[:headers].map { |k,v|
        [k.tr("-","_").downcase.to_sym,v[0]]
      }]
      ret[:headers][:content_length] = ret[:headers][:content_length].to_i
      ret[:headers][:date] = Time.parse(ret[:headers][:date]) rescue ret[:headers][:date]
      ret[:code] = response.code.to_i
      ret
    end
    def self.get(url, options = {})
      params = options[:params]
      if params.is_a?(Hash)
        params = URI.encode_www_form(params)
      end
      if params.is_a?(String)
        if url =~ /\?/
          url << "&"
        else
          url << "?"
        end
        url << params
      end
      parse_options(options)
      (http, uri) = parse_url(url, options)
      resp = http.get(uri.request_uri, options[:header])
      parse_response(resp)
    end
    def self.post(url, body = nil, options = {})
      uri = parse_url(url,options)
      if body.is_a?(Hash)
        body = URI.encode_www_form(body)
      end
      parse_options(options)
      (http, uri) = parse_url(url, options)
      resp = http.post(uri.request_uri, body, options[:header])
      parse_response(resp)
    end
  end
end

