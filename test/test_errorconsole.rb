
require 'rubygems'
require 'test/unit'
require 'egalite'
require 'helper'
require 'auth/basic'
require 'errorconsole'

require 'rack/test'
require 'setup'

class T_Handler < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new
  end
  def setup
    db = Sequel.sqlite
    db.execute("
CREATE TABLE logs (
    id SERIAL PRIMARY KEY,
    severity TEXT NOT NULL,
    
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    checked_at TIMESTAMP,
    ipaddress INET,
    text TEXT,
    url TEXT,
    md5 TEXT
);
")
    db[:logs] << {:id => 1, :severity=>'exception', :ipaddress=>'127.0.0.1', :text=>'hogehoge', :md5=>'1234', :url=>'/hoge'}
    db[:logs] << {:id => 2, :severity=>'exception', :ipaddress=>'127.0.0.1', :text=>'hogehoge', :md5=>'1234', :url=>'/hoge'}
    db[:logs] << {:id => 3, :created_at => Time.now + 60, :severity=>'exception', :ipaddress=>'127.0.0.1', :text=>'piyopiyo', :md5=>'5678', :url=>'/hoge'}
    db[:logs] << {:id => 4, :severity=>'security', :ipaddress=>'127.0.0.1', :text=>'foobar', :md5=>'1111', :url=>'/hoge'}
    
    EgaliteErrorController.database=db
    EgaliteErrorController.password='9999'
  end
  def test_latest
    basic_authorize('admin','9999')
    get "/egalite/error/latest/1"
    assert_match %r|5678</a></td><td>1</td>|, last_response.body
    assert_no_match %r|1234</a></td><td>2</td>|, last_response.body
    assert_no_match %r|1111</a></td><td>1</td>|, last_response.body
  end
  def test_frequent
    basic_authorize('admin','9999')
    get "/egalite/error/frequent/1"
    assert_match %r|1234</a></td><td>2</td>|, last_response.body
    assert_no_match %r|1111</a></td><td>1</td>|, last_response.body
    assert_no_match %r|5678</a></td><td>1</td>|, last_response.body
  end
  def test_security
    basic_authorize('admin','9999')
    get "/egalite/error/security"
    assert_no_match %r|5678</a></td><td>1</td>|, last_response.body
    assert_no_match %r|1234</a></td><td>2</td>|, last_response.body
    assert_match %r|1111</a></td><td>1</td>|, last_response.body
  end
  def test_group
    basic_authorize('admin','9999')
    get "/egalite/error/group/1234"
    assert_match %r|<li>/hoge</li>\n*<li>hogehoge</li>|, last_response.body
  end
  def test_detail
    basic_authorize('admin','9999')
    get "/egalite/error/detail/1"
    assert_not_equal "no record found.", last_response.body
    assert_match %r|<li>127.0.0.1</li>\n*<li>/hoge</li>\n*<li>hogehoge</li>|, last_response.body
    
    get "/egalite/error/detail/100"
    assert_equal "no record found.", last_response.body
  end
  def test_delete
    basic_authorize('admin','9999')
    get "/egalite/error/latest"
    assert_match %r|5678</a></td><td>1</td>|, last_response.body
    assert_match %r|1234</a></td><td>2</td>|, last_response.body

    get "/egalite/error/delete/1234"
    assert last_response.redirect?
    assert_equal "/egalite/error", last_response.headers['location']
    
    get "/egalite/error/latest"
    assert_match %r|5678</a></td><td>1</td>|, last_response.body
    assert_no_match %r|1234</a></td><td>2</td>|, last_response.body
  end
end
