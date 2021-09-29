$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'test/unit'
require 'lib/egalite/sendmail'
require 'dkim'

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
      $1.unpack('m')[0].force_encoding('UTF-8')
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
    assert_equal 'あいうえお', b.unpack('m')[0].force_encoding('UTF-8')
    assert_equal '1.0', h['MIME-Version']
    assert Time.rfc822(h['Date'])
    assert_equal 'base64', h['Content-Transfer-Encoding']
    assert_equal 'text/plain; charset=UTF-8', h['Content-Type']
  end
  def params
    {
      :date => Time.at(0),
      :from => 'hoge@example.com',
      :to   => [Sendmail.address('arai@example.com','新井俊一'),
                ['tanaka@example.com','田中太郎'],
                ['takeda@example.com','武田一郎'],
                'ueno@example.com'
               ],
      :cc   => {'Foo Bar' => 'foo@example.com',
                'Foo Who' => 'who@example.com'},
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
    assert_equal 'あいうえお', b.unpack('m')[0].force_encoding('UTF-8')
    assert_equal '1.0', h['MIME-Version']
    assert_equal Time.at(0), Time.rfc822(h['Date'])
    assert_equal 'base64', h['Content-Transfer-Encoding']
    assert_equal 'text/plain; charset=UTF-8', h['Content-Type']
    assert_equal 'hoge@example.com', h['From']
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\=\n?\Z/, h['Subject']
    h['Subject'] =~ /\A\=\?UTF-8\?B\?(.+?)\?\=/
    assert_equal 'こんにちは', $1.unpack('m')[0].force_encoding('UTF-8')
    to = h['To']
    tos = to.split(/\s*,\s+/)
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\= <arai@example.com>\Z/, tos[0]
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\= <tanaka@example.com>\Z/, tos[1]
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\= <takeda@example.com>\Z/, tos[2]
    assert_match /\Aueno@example.com\Z/, tos[3]
    to =~ /\A\=\?UTF-8\?B\?(.+?)\?\=.+?\=\?UTF-8\?B\?(.+?)\?\=.+?\=\?UTF-8\?B\?(.+?)\?\=/
    (a,b,c) = [$1,$2,$3].map { |s| s.unpack('m')[0].force_encoding('UTF-8') }
    assert_match '新井俊一', a
    assert_match '田中太郎', b
    assert_match '武田一郎', c
    assert_match '"Foo Bar" <foo@example.com>', h['Cc']
    assert_match '"Foo Who" <who@example.com>', h['Cc']
    assert_match '"Baz Bzz" <baz@example.com>', h['Reply-To']
    assert_nil h['Bcc']
  end
  def test_to_addresses
    a = Sendmail.to_addresses(params)
    %w[foo@example.com who@example.com arai@example.com tanaka@example.com takeda@example.com ueno@example.com zzz@example.com].each { |s|
      assert a.include?(s)
    }
  end
  def test_mock
    Sendmail.mock = true
    Sendmail.force_dkim = false
    Sendmail.send("Hello",:from => "arai@example.com", :to => "to@example.com")
    assert_match "To: to@example.com\n", Sendmail.lastmail[0]
    assert_match "From: arai@example.com\n", Sendmail.lastmail[0]
    assert_match "\n\nHello", Sendmail.lastmail[0]
  end
  def test_dkim
    Sendmail.mock = true
    Sendmail.force_dkim = true
    Dkim::domain = "example.com"
    Dkim::selector = "test"
    Dkim::private_key = <<EOS
-----BEGIN RSA PRIVATE KEY-----
MIICXgIBAAKBgQCkCI0PP7LbLEHyicGUrxGdA3ByTvdluRTEumu+AMNYIZaHL1oA
9ShXrhRxX14f80jXSbOhzjbauuMwv0ypwuPbuxn2rDcg7qaHUu/9lzi9SJ/h5d8/
pYyuxXcg5WRfpv1YXV7zpRzlqg4WZzMMfsxekN/Td+tw/R+SdANp0gsYFwIDAQAB
AoGAHTgQuHimSXhWvvde7jdJMejc7N+4HfycAHccnhnQsjA5ehcrNyR0bTnrFk7g
m1xgy0iroNT03H2R3qsU4uB+aeqVyy2v/RgsKGQla3xMcxj78aQYYlGYwIQ6GAeX
mEgWo+9NA5A7ecYx2Kp5FzP6r2Ha9hu59ziJmMfADOt6DiECQQDV2Iadq6+HQ4c5
hhec5fYd7ozZ87sulSFQU2ykdGmMPDq9aOu5hO7KRky7ixu0rHpKoFEnDBO8nvIh
7JDdoIyZAkEAxF5NM3KaJQB7jaRTUoYEfiz/nCs797YGqPdm2dXH4o1GXs+Xnbj9
SN9zyg4X4zbBe6jmpfSoltdZSOeY+eCILwJBAMWl/D3sui6eBnTvcBGvJjxiCMNF
l8MlSQYyJR8XDZr07CG2wPDWYdKJCVDp8PCb3eftpzQc4H0ct5UNTpPZWTkCQQCu
nkT8aP6VxNYZ4HSPv8kjApTSpMeQwXcurcHyF97FoWdgTC3A/Y2OTdZDaUDotfpc
IpfoH6YDbMBiykAIhBfVAkEAnvNjsnUsNrH3I31/0/+00EtjVxOUM+p1zaUaxtEt
nl+7ExHmNd0+V7EZzAePUjHWUIAOrj0p+AQQfglpCVXcvw==
-----END RSA PRIVATE KEY-----
EOS
    Sendmail.send("Hello",:from => "arai@example.com", :to => "to@example.com")
    assert_match "DKIM-Signature:", Sendmail.lastmail[0]
  end
  def test_verify_address
    assert Sendmail.verify_address("test@gmail.com")
    assert_equal false, Sendmail.verify_address("test@example.jp")
    assert_equal true, Sendmail.verify_address("test@example.com")
  end
  def test_attachment
    Sendmail.mock = true
    Sendmail.force_dkim = false
    tf = Tempfile.open("z")
    tf.print "piyo"
    tf.rewind
    file = {
      :filename => File.basename("test/static/test.txt"),
      :type => "text/plain",
      :name => "test.txt",
      :tempfile => tf,
      :head => "Content-Disposition: form-data; name=\"test.txt\"; filename=\"#{File.basename("test/static/test.txt")}\"\r\n" +
               "Content-Type: text/plain\r\n" +
               "Content-Length: 4\r\n"
    }
    Sendmail.send_with_uploaded_files("test",[file],:from => "arai@example.com", :to => "to@example.com")
    Sendmail.lastmail[0] =~ /boundary="(.+?)"/
    boundary = $1
    assert_match "dGVzdA==", Sendmail.lastmail[0]
    assert_match "cGl5bw==", Sendmail.lastmail[0]
    assert_match "--#{boundary}--", Sendmail.lastmail[0]
  end
  def test_override_server
    Sendmail.override_server = "example.com"
    Sendmail.send("Hello",:from => "arai@example.com", :to => "to@example.com")
    assert_match "example.com", Sendmail.lastmail[3]
    Sendmail.override_server = nil
  end
end

