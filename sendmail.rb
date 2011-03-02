
require 'template'
require 'nkf'
require 'time'

# mailheaders
# {
#   :date => Time.new,
#   :from => 'ARAI Shunichi <arai@example.com>', # encoded by Sendmail.address
#   :reply_to => ,
#   :to => 'tanaka@example.com', # encoded by Sendmail.address
#   :cc => '', # encoded by Sendmail.address
#   :bcc => '',
#   :message_id => '',
#   :in_reply_to => '',
#   :references => '',
#   :subject => '',
# }

class Sendmail
 class <<self
  def folding(h, s) # folding white space. see RFC5322, section 2.3.3 and 3.2.2.
    len = 78 - h.size - ": ".size
    len2nd = 78 - " ".size
    lines = []
    line = ""
    s.split(/\s+/).each { |c| # each word (according to gmail's behavior)
      if (line+c).size > len
        len = len2nd
        lines << line.sub(/\s+\Z/,'')
        line = c + " "
      else
        line << c + " "
      end
    }
    lines << line.sub(/\s+\Z/,'') if line.size > 0
    lines.join("\n ")
  end
  def multibyte_folding(h, s, encoding = 'UTF-8') # RFC2047
    bracketsize = "=?#{encoding}?B??=".size
    len = 76 - h.size - ": ".size - bracketsize
    len2nd = 76 - bracketsize
    lines = []
    line = ""
    s = s.gsub(/\s+/, ' ')
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
  def encode_phrase(header, s)
    if s.each_byte.any? { |c| c > 0x7f }
      multibyte_folding(header, s)
    else
      folding(header, quote_string(s))
    end
  end
  def encode_unstructured(header, s)
    if s.each_byte.any? { |c| c > 0x7f }
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
    # no support for group mail, mailbox-list and address-list.
    raise 'invalid mail address.' unless parse_addrspec(addrspec)
    if name and name.size > 0
      "#{encode_phrase(header, name)}\n <#{addrspec}>" # folded style
    else
      addrspec
    end
  end
  def send_with_template(subject, filename,to,values,from = 'support@maysee.jp')
    File.open("mail/"+ filename ,"r") { |f|
      text = f.read
      tengine = Egalite::HTMLTemplate.new
      tengine.default_escape = false
      text = tengine.handleTemplate(text,values)
      send(subject,text,to,from)
    }
  end
  def send(subject,text,to,from,from_name,to_name,envelope_from)
    text = [text].pack('m')
    subject = NKF.nkf("-WwMm0", subject)
    from_name = NKF.nkf("-WwMm0", from_name)
    to_name = NKF.nkf("-WwMm0", to_name)
    to = [to].flatten
    headers = "MIME-Version: 1.0\n"
    headers << "Date: #{Time.now.rfc822}\n"
    headers << "Subject: #{subject}\n"
    headers << "Content-Type: text/plain; charset=UTF-8\n"
    headers << "Content-Transfer-Encoding: base64\n"
    headers << "From: #{from_name} <#{from}>\n"
    headers << "To: #{to_name} <#{to[0]}>\n"
    headers << "\n"
    text = "#{headers}#{text}"
    Net::SMTP.start('localhost') { |smtp|
      from = envelope_from if envelope_from
      smtp.send_message(text,from, to)
    }
  end
 end
end
