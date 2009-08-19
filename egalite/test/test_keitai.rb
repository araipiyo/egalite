#!ruby -Ku

$KCODE = 'UTF8'

$LOAD_PATH << File.join(File.dirname(__FILE__), '..')
$LOAD_PATH << File.join(File.dirname(__FILE__))

require 'rubygems'
require 'test/unit'
require 'egalite'
require 'keitai/keitai'

require 'rack/test'

require 'kconv'

require 'setup'

class KeitaiController < Egalite::Keitai::Controller
  def post(id)
    return "false" unless params[:foo][:bar] == "あいうえお" # utf8
    "foobar:#{params[:foo][:bar]}"
  end
end

class T_Keitai < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Rack::Builder.new {
      use Rack::Ketai
      run Egalite::Handler.new
    }
  end
  def test_charsetconvesion
    s = "あいうえお".tosjis
    post("/keitai", {"foo[bar]" => s}, {'HTTP_USER_AGENT' => 'DoCoMo/2.0 P903i'})
    assert last_response.ok?
    assert last_response.body == "foobar:#{s}"
  end
end
