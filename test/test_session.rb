$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'lib/egalite/session'
require 'sequel'

require 'rack/test'

require 'setup'

class SessionController < Egalite::Controller
  def login(id)
    exp = nil
    exp = params[:expire].to_i if params[:expire].to_i > 0
    session.create(:user_id => id, :expire_sec => exp)
    redirect :action => :page
  end
  def page
    return redirect_to :action => :login if session[:user_id] == nil
    session[:user_id].to_s
  end
  def modify(id)
    session[:user_id] = id
    session.save
    redirect :action => :page
  end
  def logout
    session.delete
    redirect :action => :login
  end
end

class T_Session < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    db = Sequel.sqlite
    Egalite::SessionSequel.create_table(db)
    db.alter_table :sessions do
      add_column :user_id, :integer
    end
    Egalite::Handler.new(
      :db => db,
      :session_handler => Egalite::SessionSequel,
      :session_opts => {:individual_expire => true}
    )
  end
  def test_session
    get "/session/page"
    assert last_response.redirect?
    assert last_response.headers['location'] == "/session/login"
    assert last_response.headers['set-cookie'].blank?
    get "/session/login/9876"
    assert last_response.redirect?
    assert last_response.headers['location'] == "/session/page"
    assert last_response.headers['set-cookie'] =~ /^egalite_session=[0-9]+_[0-9a-z]+;\s+/
    last_response.headers['set-cookie'] =~ /expires=(.+?)(;|\Z|$)/
    t = Time.parse($1)
    assert t > (Time.now + 600)
    get "/session/page"
    assert last_response.ok?
    assert last_response.body =~ /9876/
    assert last_response.headers['set-cookie'] =~ /^egalite_session=[0-9]+_[0-9a-z]+;\s+/
    get "/session/modify/1234"
    assert last_response.redirect?
    assert last_response.headers['location'] == "/session/page"
    assert last_response.headers['set-cookie'] =~ /^egalite_session=[0-9]+_[0-9a-z]+;\s+/
    get "/session/page"
    assert last_response.ok?
    assert last_response.body =~ /1234/
    assert last_response.headers['set-cookie'] =~ /^egalite_session=[0-9]+_[0-9a-z]+;\s+/
    get "/session/logout"
    assert last_response.redirect?
    assert last_response.headers['location'] == "/session/login"
    assert last_response.headers['set-cookie'] =~ /^egalite_session=;\s+/
    get "/session/page"
    assert last_response.redirect?
    assert last_response.headers['location'] == "/session/login"
    assert last_response.headers['set-cookie'].blank?
  end
  def test_abstract_session
    session = Egalite::Session.new(nil,nil)
    assert_raise(NotImplementedError) { session.create }
    assert_raise(NotImplementedError) { session.load }
    assert_raise(NotImplementedError) { session.save }
    assert_raise(NotImplementedError) { session.delete }
  end
  def test_session_exp
    get "/session/login/9876?expire=1"
    last_response.headers['set-cookie'] =~ /expires=(.+?)(;|\Z|$)/
    t = Time.parse($1)
    assert last_response.redirect?
    assert last_response.headers['location'] == "/session/page"
    assert last_response.headers['set-cookie'] =~ /^egalite_session=[0-9]+_[0-9a-z]+;\s+/
    assert t < (Time.now + 60)
  end
end
