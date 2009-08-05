$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'rcov'
require 'test/unit'
require 'egalite'

require 'app/app'

require 'rack/test'

ShowException = true
RouteDebug = false

class TestController < Egalite::Controller
  def parameters
    raise "param foo is not bar: #{params[:foo].inspect}" unless params[:foo] == 'bar'
    raise "param hash isnt okay: #{params[:hash].inspect}" unless params[:hash][:a] == '1' and params[:hash][:b] == '2'
    "okay"
  end
  def exception
    raise
  end
end

class T_Handler < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new
  end
  def test_default_controller
    get "/"
    assert last_response.ok?
  end
  def test_exception
    get "/test/exception"
    assert last_response.ok? == false
    assert last_response.server_error?
    assert last_response.body =~ /Exception/
  end
  def test_parameters
    post("/test/parameters", {'foo' => 'bar', 'hash[a]' => '1', 'hash[b]' => '2'})
    assert last_response.ok?
    assert last_response.body =~ /okay/
    assert last_response.content_type =~ /text\/html/i
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
