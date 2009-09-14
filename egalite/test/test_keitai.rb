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
  def login(id)
    session.create(:user_id => id)
    redirect_to :controller => :mobile
  end
end
class MobileController < Egalite::Keitai::Controller
  def before_filter
    super

    return redirect_to :controller => :keitai, :action => :login unless session[:user_id].to_i > 0
    true
  end
  def get
    {}
  end
  def get_userid
    session[:user_id].to_s
  end
end

class RedirectorController < Egalite::Keitai::Redirector
end

class T_Keitai < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    db = Sequel.sqlite
    Egalite::SessionSequel.create_table(db)
    db.alter_table :sessions do
      add_column :user_id, :integer
    end

    Rack::Builder.new {
      use Rack::Ketai
      run Egalite::Handler.new(
        :db => db,
        :session_handler => Egalite::SessionSequel,
        :template_path => File.dirname(__FILE__)
      )
    }
  end
    
  def test_ctler_should_see_utf8_for_sjis_query_parameter
    s = "あいうえお".tosjis
    post("/keitai", {"foo[bar]" => s}, {'HTTP_USER_AGENT' => 'DoCoMo/2.0 P903i'})
    assert last_response.ok?
    assert_equal("foobar:#{s}", last_response.body)
  end
  def test_session
    get("/keitai/login/1234")
    assert last_response.redirect?
    assert_match(%r|/mobile\?sessionid=[0-9]+_[0-9a-f]+|,last_response.location)
    location = last_response.location
    
    clear_cookies
    
    get(location)
    assert last_response.ok?
    assert_match(%r|<a\s+href='(/mobile/get_userid\?sessionid=[0-9]+_[0-9a-f]+)'\s*>hoge</a>|,last_response.body)
    %r|<a\s+href='(/mobile/get_userid\?sessionid=[0-9]+_[0-9a-f]+)'\s*>hoge</a>| =~ last_response.body
    get_userid = $1
    assert_match(%r|<a\s+href='(/redirector/[0-9a-zA-Z._-]+)'\s*>yahoo</a>|,last_response.body)
    %r|<a\s+href='(/redirector/[0-9a-zA-Z._-]+)'\s*>yahoo</a>| =~ last_response.body
    redirector = $1
 	assert_match(%r|<form\s+action='/mobile/bar\?sessionid=[0-9]+_[0-9a-f]+'\s+method='GET'\s*>|, last_response.body)
 	
    clear_cookies
    
 	get(get_userid)
    assert last_response.ok?
    assert_equal("1234", last_response.body)

    clear_cookies

    get(redirector)
    assert last_response.redirect?
    assert_match(%r|http://www.yahoo.com|, last_response.location)
  end
end
