$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'test/unit'
require 'sendmail'

$KCODE = 'utf8'

class T_Sendmail < Test::Unit::TestCase
  def test_folding
    s = Sendmail.folding('To', "012345678  \n\n  "*20)
    a = s.split(/\n/)
    assert_equal 69, a[0].size
    assert_equal 70, a[1].size
    assert_match /\A\s[0-9\s]{69}\Z/, a[1]
    assert_equal 200-70-70, a[2].size
    s2 = Sendmail.folding('To', s)
    assert_equal s, s2
  end
  def test_encode_phrase
    s = Sendmail.encode_phrase('To', "0123\"6\\9\x00"*20)
    assert_equal "\n \"" + ('0123\\"6\\\\9'*20) + '"', s
  end
  def test_encode_unstructured
    s = Sendmail.encode_unstructured('To', "0123\"6\\9\x00"*20)
    assert_equal "\n " + ('0123"6\\9'*20), s
  end
  def test_parse_addrspec
    (local, domain) = Sendmail.parse_addrspec('"baz\\"@bar\\"@foo"@example.com')
    assert_equal '"baz\\"@bar\\"@foo"', local
    assert_equal 'example.com', domain
    (local, domain) = Sendmail.parse_addrspec('"a"@example.com')
    assert_equal '"a"', local
    assert_equal 'example.com', domain
    (local, domain) = Sendmail.parse_addrspec('bar@example.com')
    assert_equal 'bar', local
    assert_equal 'example.com', domain
    (local, domain) = Sendmail.parse_addrspec('bar@example.com.')
    assert_equal nil, local
    (local, domain) = Sendmail.parse_addrspec('bar@example..com')
    assert_equal nil, local
    (local, domain) = Sendmail.parse_addrspec('bar@example')
    assert_equal nil, local
  end
  def test_address
    s = Sendmail.address('foo@example.com', '新井 俊一', 'To')
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\= <foo@example.com>\Z/, s
    s = Sendmail.address('foo@example.com', "\x00ARAI \n Shunichi", 'To')
    assert_match /"ARAI Shunichi" <foo@example.com>\Z/, s
  end
  def test_multibyte_folding
    s = Sendmail.multibyte_folding('Subject', 'あいうえお'*20)
    a = s.split(/\n/)
    assert "Subject: #{a[0]}".size < 76
    s2 = a.map { |e|
      assert e.size < 77
      assert_match /\A\s?\=\?UTF-8\?B\?(.+?)\?\=\Z/, e
      e =~ /\=\?UTF-8\?B\?(.+?)\?\=/
      $1.unpack('m')[0]
    }.join
    assert_equal 'あいうえお'*20, s2
  end
  def test_mailboxlist
    s = Sendmail.mailboxlist('foo@example.com')
    assert_equal 'foo@example.com',s
  end
  def parse_message(s)
    (header, body) = s.split(/\n\n/,2)
    headers = {}
    header.gsub(/\n[\s\t]+/, ' ').split(/\n/).each { |line|
      (k,v) = line.split(/: +/,2)
      headers[k] = v
    }
    [headers, body]
  end
  def test_message_7bit
    s = Sendmail.message('hoge',:from=>'hoge@example.com',:subject=>'test')
    (h,b) = parse_message(s)
    assert_equal 'hoge', b
    assert_equal '1.0', h['MIME-Version']
    assert Time.rfc822(h['Date'])
    assert_equal '7bit', h['Content-Transfer-Encoding']
    assert_equal 'text/plain; charset=UTF-8', h['Content-Type']
    assert_equal 'test', h['Subject']
  end
  def test_message_multibyte
    s = Sendmail.message('あいうえお',:from=>'hoge@example.com')
    (h,b) = parse_message(s)
    assert_equal 'あいうえお', b.unpack('m')[0]
    assert_equal '1.0', h['MIME-Version']
    assert Time.rfc822(h['Date'])
    assert_equal 'base64', h['Content-Transfer-Encoding']
    assert_equal 'text/plain; charset=UTF-8', h['Content-Type']
  end
  def params
    {
      :date => Time.local(0),
      :from => 'hoge@example.com',
      :to   => [Sendmail.address('arai@example.com','新井俊一'),
                ['tanaka@example.com','田中太郎'],
                {:address => 'takeda@example.com', :name => '武田一郎'},
                'ueno@example.com'
               ],
      :cc   => Sendmail.address('foo@example.com', 'Foo Bar'),
      :bcc  => Sendmail.address('zzz@example.com', 'zzz'),
      :reply_to=> Sendmail.address('baz@example.com', 'Baz Bzz'),
      :subject => 'こんにちは',
    }
  end
  def test_message_headers
    assert_raise(RuntimeError) { Sendmail.message('',{}) }
    assert_raise(RuntimeError) { Sendmail.message('',{:sender => ['1','2']}) }
    assert_raise(RuntimeError) { Sendmail.message('',{:from => [1,2,3]}) }
    s = Sendmail.message('あいうえお',params)
    (h,b) = parse_message(s)
    assert_equal 'あいうえお', b.unpack('m')[0]
    assert_equal '1.0', h['MIME-Version']
    assert_equal Time.local(0), Time.rfc822(h['Date'])
    assert_equal 'base64', h['Content-Transfer-Encoding']
    assert_equal 'text/plain; charset=UTF-8', h['Content-Type']
    assert_equal 'hoge@example.com', h['From']
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\=\n?\Z/, h['Subject']
    h['Subject'] =~ /\A\=\?UTF-8\?B\?(.+?)\?\=/
    assert_equal 'こんにちは', $1.unpack('m')[0]
    to = h['To']
    tos = to.split(/\s*,\s+/)
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\= <arai@example.com>\Z/, tos[0]
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\= <tanaka@example.com>\Z/, tos[1]
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\= <takeda@example.com>\Z/, tos[2]
    assert_match /\Aueno@example.com\Z/, tos[3]
    to =~ /\A\=\?UTF-8\?B\?(.+?)\?\=.+?\=\?UTF-8\?B\?(.+?)\?\=.+?\=\?UTF-8\?B\?(.+?)\?\=/
    (a,b,c) = [$1,$2,$3].map { |s| s.unpack('m')[0] }
    assert_match '新井俊一', a
    assert_match '田中太郎', b
    assert_match '武田一郎', c
    assert_match '"Foo Bar" <foo@example.com>', h['Cc']
    assert_match '"Baz Bzz" <baz@example.com>', h['Reply-To']
    assert_nil h['Bcc']
  end
  def test_to_addresses
    a = Sendmail.to_addresses(params)
    %w[foo@example.com arai@example.com tanaka@example.com takeda@example.com ueno@example.com zzz@example.com].each { |s|
      assert a.include?(s)
    }
  end
end
