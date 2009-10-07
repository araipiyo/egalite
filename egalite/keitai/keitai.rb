
$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'ketai'
require 'uri'
require 'openssl'
require 'base64'

module Egalite
  module Keitai
    class URLSession
      def self.encrypt(s,key)
        cipher = OpenSSL::Cipher.new("bf-cbc")
        cipher.pkcs5_keyivgen(key)
        cipher.encrypt
        e = cipher.update(s) + cipher.final
        Base64.encode64(e).tr('+/=','_.-').chomp!
      end
      def self.decrypt(s,key)
        cipher = OpenSSL::Cipher.new("bf-cbc")
        cipher.pkcs5_keyivgen(key)
        cipher.decrypt
        e = s.tr('_.-','+/=')
        e = Base64.decode64(e)
        d = cipher.update(e) + cipher.final
        d
      end
    end
    module Session
      def load_keitai_session(sessionid)
        session.load_from_param(sessionid)
      end
      def modify_url_for_keitai(url,sstr)
        uri = URI.parse(URI.escape(url))
        if uri.host and uri.host !~ my_host
          crypted_url = URLSession.encrypt(url,redirector_crypt_key)
          File.join(redirector_url,crypted_url)
        else
          array = uri.query.to_s.split('&')
          qhash = array.inject({}) { |a,s| (k,v) = s.split('=',2); a[k] = v; a }
          qhash['sessionid']=sstr
          uri.query = qhash.map {|k,v| "#{k}=#{v}"}.join('&')
          uri.to_s
        end
      end
      def replace_url_for_keitai(body,sstr)
        body.gsub!(/<a.+?href=(?:'(.+?)'|"(.+?)").+?>/) { |s|
          url = ($1 || $2)
          url_after = modify_url_for_keitai(url,sstr)
          s.sub(url,url_after)
        }
        body.gsub!(/(<form.+?>)/) { |s|
          s + "\n<input type='hidden' name='sessionid' value='#{sstr}'/>\n"
        }
      end
      def redirector_url
        "/redirector"
      end
      def do_after_filter_for_keitai(response,session)
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
        response
      end
    end
    class Controller < Egalite::Controller
      include Session
      
      def before_filter
        load_keitai_session(params[:sessionid])
        super
      end
      def redirector_crypt_key
        "Example1"
      end
      def my_host
        /^www.example.com$/
      end
      def after_filter(response)
        do_after_filter_for_keitai(response,session)
        super(response)
        response
      end
    end
    
    class Redirector < Egalite::Controller
      def get(crypted_url)
        url = URLSession.decrypt(crypted_url, redirector_crypt_key)
        "<html><body>外部サイトへ移動しようとしています。以下のリンクをクリックしてください。<br/><br/><a href='#{url}'>リンク</a></body></html>"
      end
      def redirector_crypt_key
        "Example1"
      end
    end

  end
end
