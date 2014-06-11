
require 'nkf'
require 'time'
require 'net/smtp'
require 'resolv'

# mailheaders
# {
#   :date => Time.new,
#   :from => {'ARAI Shunichi' => 'arai@example.com'},
#   :reply_to => ,
#   :to => 'tanaka@example.com',
#   :cc => '',
#   :bcc => '',
#   :message_id => '',
#   :in_reply_to => '',
#   :references => '',
#   :subject => '',
# }

# many ways to designate mail addresses.
# 1. array: you can put multiple addresses (string) into array.
# 1b array of array: 
#  [["hoge@example.com","Hoge Taro"]]
# 2. simple string: "mailaddress@example.com" works just fine.
# 3. encoded string: Sendmail.address("hoge@example.com", "Hoge Taro")
# 4. hash: { "Hoge Taro" => "hoge@example.com" }

module Sendmail
 class QualifiedMailbox < String
 end
 @force_dkim = false
 @mock = false
 class <<self
  attr_accessor :mock, :force_dkim
  attr_reader :lastmail
  def folding(h, s) # folding white space. see RFC5322, section 2.3.3 and 3.2.2.
    len = 78 - h.size - ": ".size
    len2nd = 78 - " ".size
    lines = []
    line = ""
    s.strip.split(/\s+/).each { |c| # each word (according to gmail's behavior)
      if (line+c).size > len
        len = len2nd
        lines << line.strip
        line = c + " "
      else
        line << c + " "
      end
    }
    lines << line.strip if line.size > 0
    lines.join("\n ")
  end
  def multibyte_folding(h, s, encoding = 'UTF-8') # RFC2047
    bracketsize = "=?#{encoding}?B??=".size
    len = 76 - h.size - ": ".size - bracketsize
    len2nd = 76 - bracketsize
    lines = []
    line = ""
    s = s.gsub(/\s+/, ' ').strip
    s.split(//).each { |c| # each character (including multi-byte ones)
      teststr = line+c
      teststr = NKF.nkf('-Wj',teststr) if encoding =~ /iso-2022-jp/i
      if [teststr].pack('m').chomp.size > len
        len = len2nd
        lines << line
        line = c
      else
        line << c
      end
    }
    lines << line if line.size > 0
    lines = lines.map { |s| "=?#{encoding}?B?#{[s].pack('m').gsub(/\n/,'')}?=" }
    lines.join("\n ")
  end
  def vchar(s)
    s.gsub(/[\x00-\x1f\x7f]/,'')
  end
  def wsp(s)
    s.gsub(/\s+/,' ')
  end
  def quote_string(s)
    '"' + vchar(wsp(s)).gsub(/\\/,"\\\\\\").gsub(/\"/,'\\\"') + '"'
  end
  def multibyte?(s)
    s.each_byte.any? { |c| c > 0x7f }
  end
  def encode_phrase(header, s)
    if multibyte?(s)
      multibyte_folding(header, s)
    else
      folding(header, quote_string(s))
    end
  end
  def encode_unstructured(header, s)
    if multibyte?(s)
      multibyte_folding(header, s)
    else
      folding(header, vchar(wsp(s)))
    end
  end
  def atext; '[0-9a-zA-Z!#$%&\'*+\-/=?\^_`{|}~]'; end
  def atext_loose; '[0-9a-zA-Z!#$%&\'*+\-/=?\^_`{|}~.]'; end
  
  def check_domain(s)
    s =~ /\A#{atext}+?(\.#{atext}+?)+\Z/
  end
  def check_local_loose(s)
    s =~ /\A#{atext_loose}+\Z/
  end
  def parse_addrspec(addrspec)
    # no support for CFWS, FWS, and domain-literal.
    if addrspec[0,1] == '"' # quoted-string
      addrspec =~ /\A(\".*?[^\\]\")\@(.+)\Z/
      (local, domain) = [$1, $2]
      return nil if local =~ /[\x00-\x1f\x7f]/
      return nil unless check_domain(domain)
      [local, domain]
    else
      (local, domain) = addrspec.split(/@/,2)
      return nil unless check_local_loose(local)
      return nil unless check_domain(domain)
      [local, domain]
    end
  end
  def address(addrspec, name = nil, header='Reply-to') 
    # mailbox in RFC5322 section 3.4. not 'address' as in RFC.
    raise 'invalid mail address.' unless parse_addrspec(addrspec)
    if name and name.size > 0
      QualifiedMailbox.new(folding(header, "#{encode_phrase(header, name)} <#{addrspec}>"))
    else
      addrspec
    end
  end
  def mailboxlist(value, header = 'Reply-to')
    case value
      when QualifiedMailbox
        value
      when String
        parse_addrspec(value) ? value : nil
      when Hash
        folding(header, value.map { |name, address|
          address(address,name)
        }.join(', '))
      when Array
        folding(header, value.map { |v|
          v.is_a?(Array) ? address(v[0],v[1]) : mailboxlist(v,header)
        }.join(', '))
      else
        nil
    end
  end
  def message(body, params)
    headers = {}
    
    raise "From must be exist." unless params[:from]
    raise "The number of sender must be zero or one." if params[:sender].is_a?(Array) and params[:sender].size > 1
    raise "When the number of 'from' is more than one, sender must be exist" if params[:from].is_a?(Array) and params[:from].size > 1 and not params[:sender]
    
    %w[From To Sender Reply-To Cc].each { |s|
      v = params[s.gsub(/-/,'_').downcase.to_sym]
      headers[s] = mailboxlist(v,s) if v and v.size >= 1
    }
    
    headers["Subject"] = encode_unstructured("Subject",params[:subject].to_s) if params[:subject]
    headers["MIME-Version"] = "1.0"
    date = params[:date] || Time.now
    headers["Date"] = date.is_a?(Time) ? date.rfc822 : date
    headers["Content-Type"] = "text/plain; charset=UTF-8"
    
    if multibyte?(body)
      headers["Content-Transfer-Encoding"] = "base64"
      body = [body].pack('m')
    else
      headers["Content-Transfer-Encoding"] = "7bit"
    end
    
    text = [headers.map{|k,v| "#{k}: #{v}"}.join("\n"),body].join("\n\n")
  end
  private
  def _extract_addrspec(value)
    case value
      when QualifiedMailbox
        value =~ /<(#{atext_loose}+?@#{atext_loose}+?)>\Z/
        $1
      when String
        parse_addrspec(value) ? value : nil
      when Hash
        value.values.map { |s|
          parse_addrspec(s) ? s : nil
        }
      when Array
        value.map { |v|
          if v.is_a?(Array)
            parse_addrspec(v[0]) ? v[0] : nil
          else
            _extract_addrspec(v)
          end
        }
      else nil
    end
  end
  public
  def to_addresses(params)
    addresses = [:to, :cc, :bcc].map { |s|
      _extract_addrspec(params[s])
    }
    addresses.flatten.compact.uniq
  end
  def _send(text, envelope_from, to, host = 'localhost')
    if @mock
      @lastmail = [text, envelope_from, to, host]
    else
      Net::SMTP.start(host) { |smtp|
        smtp.send_message(text, envelope_from, to)
      }
    end
  end
  def read_private_key(pem_filename)
    OpenSSL::PKey::RSA.new(open(pem_filename).read)
  end
  def send_inner_2(body, params, host, dkim, dkim_params)
    text = message(body, params)
    if dkim
      text = Dkim.sign(text,dkim_params)
    end
    _send(
      text,
      _extract_addrspec(params[:envelope_from] || params[:sender] || params[:from]),
      to_addresses(params),
      host
    )
  end
  def send(body, params, host = 'localhost')
    send_inner_2(body, params, host, @force_dkim, {})
  end
  def send_with_dkim(body, params, host = 'localhost', dkim_params = {})
    send_inner_2(body, params, host, true, dkim_params)
  end
  def send_with_template(filename, params, host = 'localhost')
    File.open("mail/"+ filename ,"r") { |f|
      text = f.read
      tengine = Egalite::HTMLTemplate.new
      tengine.default_escape = false
      text = tengine.handleTemplate(text,params)
      send(text, params, host)
    }
  end
  
  #
  # check validity of email address with DNS lookup.
  #
  def verify_address(email)
    (local,domain) = parse_addrspec(email)
    return false unless domain
    mx = Resolv::DNS.new.getresource(domain, Resolv::DNS::Resource::IN::MX) rescue nil
    return true if mx
    a = Resolv::DNS.new.getresource(domain, Resolv::DNS::Resource::IN::A) rescue nil
    return true if a
    aaaa = Resolv::DNS.new.getresource(domain, Resolv::DNS::Resource::IN::AAAA) rescue nil
    return true if aaaa
    false
  end
 end
end
