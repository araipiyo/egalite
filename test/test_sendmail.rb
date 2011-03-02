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
    assert_match /\A\=\?UTF-8\?B\?(.+?)\?\=\n <foo@example.com>\Z/, s
    s = Sendmail.address('foo@example.com', "\x00ARAI \n Shunichi", 'To')
    assert_match /"ARAI Shunichi"\n <foo@example.com>\Z/, s
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
end

