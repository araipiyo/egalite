$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'

require 'rack/test'

require 'setup'

class TestController < Egalite::Controller
  def parameters
    raise "param foo is not bar: #{params[:foo].inspect}" unless params[:foo] == 'bar'
    raise "param hash isnt okay: #{params[:hash].inspect}" unless params[:hash][:a] == '1' and params[:hash][:b] == '2'
    "okay"
  end
  def exception
    raise
  end
  def notfoundtest
    notfound
  end
  def delegatetest
    delegate(:action => :test)
  end
  def test
    "delegated"
  end
  def niltest
    nil
  end
  def ipaddr
    req.ipaddr.to_s
  end
end
class BeforefilterController < TestController
  def before_filter
    case params[:test]
      when /notfound/: notfound
      when /delegate/: delegate(:controller => :test,:action => :test)
      when /forbidden/: false
      else redirect(:action => :test)
    end
  end
end


class T_Handler < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new
  end
  def test_exception
    get "/test/exception"
    assert last_response.server_error?
    assert last_response.body =~ /Exception/
  end
  def test_parameters
    post("/test/parameters", {'foo' => 'bar', 'hash[a]' => '1', 'hash[b]' => '2'})
    assert last_response.ok?
    assert last_response.body =~ /okay/
    assert last_response.content_type =~ /text\/html/i
  end
  def test_notfound
    get "/test/notfoundtest"
    assert last_response.not_found?
  end
  def test_delegate
    get "/test/delegatetest"
    assert last_response.ok?
    assert last_response.body =~ /delegated/
  end
  def test_nil
    get "/test/niltest"
    assert last_response.server_error?
    assert last_response.body =~ /Exception/
    assert last_response.body =~ /nil/
  end
  def test_beforefilter
    get "/beforefilter/niltest"
    assert last_response.redirect?
    assert last_response.headers['location'] == "/beforefilter/test"
    get "/beforefilter/niltest?test=delegate"
    assert last_response.ok?
    assert last_response.body =~ /delegated/
    get "/beforefilter/niltest?test=notfound"
    assert last_response.not_found?
    get "/beforefilter/niltest?test=forbidden"
    assert last_response.forbidden?
  end
  def test_ipaddr
    get "/test/ipaddr"
    assert last_response.ok?
    assert last_response.body =~ /[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/
  end
end

class T_StaticController < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new(:static_root=>'test/static/')
  end
  def test_default_controller
    get "/static/foo"
    assert last_response.ok? == false
    assert last_response.not_found?
    get "/static/../../hoge/hoge/"
    assert last_response.ok? == false
    assert last_response.forbidden?
    get "/static/test.txt"
    assert last_response.ok?
    assert last_response.body =~ /piyo/
  end
end
