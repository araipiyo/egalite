$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'

require 'rack/test'

require 'setup'

class DefaultController < Egalite::Controller
  def get(s)
    return url_for(:action => :pathtest) if s == "NoControllerNoAction1"
    return url_for(:controller => :route, :action => :pathtest) if s == "NoControllerNoAction2"
    
    s ? s : "root"
  end
  def hashparams
    url_for({:hoge => {:a => 1, :b => 2}})
  end
  def stringparams
    url_for(:params => :abc)
  end
  def pathtest
    req.path
  end
  def urltest
    url_for(:controller => :route, :action => :foo, :id => '1', :hoge => :piyo)
  end
  def urltest2
    url_for(:action => :pathtest, :id => '1', :hoge => :piyo)
  end
  def linkto
    link_to("nya",:controller => :route, :action => :foo, :id => '1', :hoge => :piyo)
  end
  def https
    url_for(:action => :hoge, :scheme => :https)
  end
  def host
    url_for(:action => :piyo, :host => 'hoge.example.org')
  end
end

class RouteController < Egalite::Controller
  def get(s)
    s ? s : "null"
  end
  def pathtest
    req.path
  end
  def urltest
    url_for(:controller => '/', :action => :pathtest, :id => '1', :hoge => :piyo)
  end
  def urltest2
    url_for(:action => :pathtest, :id => '1', :hoge => :piyo)
  end
  def urltest3
    url_for(:controller => 'noactionroute', :action => :pathtest, :id => '1', :hoge => :piyo)
  end
  def urltest4
    url_for(:controller => :route, :action => nil, :id => 1)
  end
end

class OneSlashController < Egalite::Controller
  def get(s)
    s ? s : "oneslash"
  end
  def pathtest
    req.path
  end
  def urltest
    url_for(:controller => '/', :action => :pathtest, :id => '1', :hoge => :piyo)
  end
  def urltest2
    url_for(:action => :pathtest, :id => '1', :hoge => :piyo)
  end
end

class NoactionrouteController < Egalite::Controller
  def get
    url_for(:action => :foo, :id => '1', :hoge => :piyo)
  end
end

class T_Session < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    Egalite::Handler.new
  end
  def test_root
    get "/"
    assert last_response.ok?
    assert last_response.body == "root"
    get "/piyo"
    assert last_response.ok?
    assert last_response.body == "piyo"
    get "/hashparams"
    assert last_response.ok?
    assert last_response.body == "/hashparams?hoge[a]=1&hoge[b]=2"
    get "/stringparams"
    assert last_response.ok?
    assert last_response.body == "/stringparams/abc"
    get "/https"
    assert last_response.ok?
    assert last_response.body == "https://example.org/hoge"
    get "/host"
    assert last_response.ok?
    assert last_response.body == "http://hoge.example.org/piyo"
  end
  def test_path
    get "/pathtest/"
    assert last_response.ok?
    assert last_response.body == ""
    get "/pathtest/a"
    assert last_response.ok?
    assert last_response.body == "a"
    get "/pathtest/a/b/c"
    assert last_response.ok?
    assert last_response.body == "a/b/c"
  end
  def test_noslash
    get "/route/"
    assert last_response.ok?
    assert last_response.body == "null"
    get "/route/hoge"
    assert last_response.ok?
    assert last_response.body == "hoge"
    get "/route/pathtest"
    assert last_response.ok?
    assert last_response.body == ""
    get "/route/pathtest/a/b/c"
    assert last_response.ok?
    assert last_response.body == "a/b/c"
  end
  def test_oneslash
    get "/one/slash"
    assert last_response.ok?
    assert last_response.body == "oneslash"
    get "/one/slash/hoge"
    assert last_response.ok?
    assert last_response.body == "hoge"
    get "/one/slash/pathtest"
    assert last_response.ok?
    assert last_response.body == ""
    get "/one/slash/pathtest/a/b/c"
    assert last_response.ok?
    assert last_response.body == "a/b/c"
  end
  def test_urltest
    get "/urltest"
    assert last_response.ok?
    assert last_response.body == "/route/foo/1?hoge=piyo"
    get "/urltest2"
    assert last_response.ok?
    assert last_response.body == "/pathtest/1?hoge=piyo"
    get "/linkto"
    assert last_response.ok?
    assert last_response.body == "<a href='/route/foo/1?hoge=piyo'>nya</a>"
    get "/route/urltest"
    assert last_response.ok?
    assert last_response.body == "/pathtest/1?hoge=piyo"
    get "/route/urltest2"
    assert last_response.ok?
    assert last_response.body == "/route/pathtest/1?hoge=piyo"
    get "/route/urltest3"
    assert last_response.ok?
    assert last_response.body == "/noactionroute/pathtest/1?hoge=piyo"
    get "/route/urltest4"
    assert last_response.ok?
    assert last_response.body == "/route/1"
    get "/one/slash/urltest"
    assert last_response.ok?
    assert last_response.body == "/pathtest/1?hoge=piyo"
    get "/one/slash/urltest2"
    assert last_response.ok?
    assert last_response.body == "/one/slash/pathtest/1?hoge=piyo"
    get "/noactionroute"
    assert last_response.ok?
    assert last_response.body == "/noactionroute/foo/1?hoge=piyo"
    get "/noactionroute/hoge"
    assert last_response.ok?
    assert last_response.body == "/noactionroute/foo/1?hoge=piyo"
    get "/NoControllerNoAction1"
    assert last_response.ok?
    assert last_response.body == "/pathtest"
    get "/NoControllerNoAction2"
    assert last_response.ok?
    assert last_response.body == "/route/pathtest"
  end
end
