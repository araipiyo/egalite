$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'
require 'auth/basic'

require 'rack/test'

require 'setup'

class AuthtestController < Egalite::Controller
  def before_filter
    Egalite::Auth::Basic.authorize(req, 'authtest') { |username,password|
      username == 'testing' and password == '1234'
    }
  end
  def test
    'okay'
  end
end

class T_Auth < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new
  end
  def test_auth_failure
    get "/authtest/test"
    assert_equal last_response.status, 401
    assert_equal last_response.headers['WWW-Authenticate'], 'Basic realm="authtest"'
    basic_authorize('testing','9999')
    get "/authtest/test"
    assert_equal last_response.status, 401
    assert_equal last_response.headers['WWW-Authenticate'], 'Basic realm="authtest"'
    basic_authorize('testing','1234')
    get "/authtest/test"
    assert last_response.ok?
    assert_equal last_response.body,'okay'
  end
end
