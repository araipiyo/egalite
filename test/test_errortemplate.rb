$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'lib/egalite'

require 'rack'
require 'rack/multipart'
require 'rack/test'

require 'setup'

class ErrorTemplateController < Egalite::Controller
  def foo
    raise Egalite::UserError.new("UserError")
  end
end

class T_ErrorTemplate < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new(
      :error_template_file => "test/error_template.html"
    )
  end
  def test_errortemplate
    $raise_exception = false
    get "/error/template/foo"
    assert_match /message: UserError/, last_response.body
    assert_match /this is usererror/, last_response.body
    $raise_exception = true
  end
end
