
$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'ketai'
require 'uri'
require 'openssl'
require 'base64'

module Egalite
  module Keitai
    class URLSession
      def self.encrypt(s)
        cipher = OpenSSL::Cipher.new("bf-cbc")
        cipher.pkcs5_keyivgen("pl4@a*+1")
        cipher.encrypt
        e = cipher.update(s) + cipher.final
        Base64.encode64(e).tr('+/=','_.-').chomp!
      end
      def self.decrypt(s)
        cipher = OpenSSL::Cipher.new("bf-cbc")
        cipher.pkcs5_keyivgen("pl4@a*+1")
        cipher.decrypt
        e = s.tr('_.-','+/=')
        e = Base64.decode64(e)
        d = cipher.update(e) + cipher.final
        d
      end
    end
    class Controller < Egalite::Controller
      def before_filter
        session.load_from_param(params[:sessionid])
        super
      end
      def modify_url_for_keitai(url,sstr)
        uri = URI.parse(url)
        if uri.host and uri.host !~ my_host
          crypted_url = URLSession.encrypt(url)
          File.join(redirector_url,crypted_url)
        else
          array = uri.query.to_s.split('&')
          qhash = array.inject({}) { |a,s| (k,v) = s.split('=',2); a[k] = v; a }
          qhash['sessionid']=sstr
          uri.query = qhash.map {|k,v| "#{k}=#{v}"}.join
          uri.to_s
        end
      end
      def replace_url_for_keitai(body,sstr)
        body.gsub!(/<a.+?href=(?:'(.+?)'|"(.+?)").+?>/) { |s|
          url = ($1 || $2)
          url_after = modify_url_for_keitai(url,sstr)
          s.sub(url,url_after)
        }
        body.gsub!(/<form.+?action=(?:'(.+?)'|"(.+?)").+?>/) { |s|
          url = ($1 || $2)
          url_after = modify_url_for_keitai(url,sstr)
          s.sub(url,url_after)
        }
      end
      def my_host
        /^www.example.com$/
      end
      def redirector_url
        "/redirect"
      end
      def after_filter(response)
        code = response[0]
        headers = response[1]
        body = response[2].join

        if session and session.sstr
          sstr = session.sstr
          if headers['Location']
            headers['Location'] = modify_url_for_keitai(headers['Location'],sstr)
          end
          replace_url_for_keitai(body,sstr)
          response[2] = [body]
        end
        
        super(response)
        response
      end
    end
    
    class Redirector < Egalite::Controller
      def get(crypted_url)
        redirect_to URLSession.decrypt(crypted_url)
      end
    end

  end
end