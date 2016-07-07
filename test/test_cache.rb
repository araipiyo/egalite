$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'sequel'
require 'test/unit'
require 'egalite'
require 'egalite/cache'

require 'rack'
require 'rack/test'

require 'setup'

class TestCacheController < Egalite::Controller
  include Egalite::ControllerCache
  
  cache_action :get, :expire => 1
  
  def get
    "#{Time.now.to_i}.#{Time.now.usec}"
  end
  def nocache
    "#{Time.now.to_i}.#{Time.now.usec}"
  end
end

class TestCachewithqueryController < Egalite::Controller
  include Egalite::ControllerCache

  cache_action :get, :expire => 1, :with_query => true

  def get
    "#{Time.now.to_i}.#{Time.now.usec}"
  end
  def nocache
    "#{Time.now.to_i}.#{Time.now.usec}"
  end
end

class CacheController < Egalite::Controller
  include Egalite::ControllerCache
  
  cache_action :cache, :expire => 1
  
  def get
    {}
  end
  def cache
    {:time => "#{Time.now.to_i}.#{Time.now.usec}"}
  end
  def nocache
    {:time => "#{Time.now.to_i}.#{Time.now.usec}"}
  end
end

class T_Cache < Test::Unit::TestCase
  include Rack::Test::Methods
  
  def app
    db = Sequel.sqlite
    Egalite::ControllerCache.create_table(db)
    Egalite::ControllerCache.table = db[:controller_cache]
    Egalite::Handler.new
  end
  def test_cache
    # test cache is not working
    get "/test/cache/nocache"
    a = last_response.body
    sleep 0.1
    get "/test/cache/nocache"
    b = last_response.body
    assert_not_equal a,b
    
    # test cache is working
    get "/test/cache/"
    a = last_response.body
    sleep 0.1
    get "/test/cache/"
    b = last_response.body
    assert_equal a,b
    sleep 2
    get "/test/cache/"
    c = last_response.body
    assert_not_equal a,c
    
    # test cache is not working for different url
    get "/test/cache/1"
    a = last_response.body
    sleep 0.1
    get "/test/cache/2"
    b = last_response.body
    assert_not_equal a,b
  end
  def test_cache_with_query
    # test cache is not working
    get "/test/cachewithquery/nocache"
    a = last_response.body
    sleep 0.1
    get "/test/cachewithquery/nocache"
    b = last_response.body
    assert_not_equal a,b

    # test cache is working
    get "/test/cachewithquery?a=1"
    a = last_response.body
    sleep 0.1
    get "/test/cachewithquery?a=1"
    b = last_response.body
    assert_equal a,b

    # test cache is not working for different url
    get "/test/cachewithquery?a=1"
    a = last_response.body
    sleep 0.1
    get "/test/cachewithquery?a=2"
    b = last_response.body
    assert_not_equal a,b
    sleep 0.1
    get "/test/cachewithquery?a=1&b=2"
    c = last_response.body
    assert_not_equal a,c
  end
end

# テンプレートでのテスト
class T_CacheTemplate < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    db = Sequel.sqlite
    Egalite::ControllerCache.create_table(db)
    Egalite::ControllerCache.table = db[:controller_cache]
    Egalite::Handler.new(:template_path => File.dirname(__FILE__))
  end
  def test_cache
    # test cache is not working
    get "/cache/"
    last_response.body =~ /nocache:(.+?)\n/
    a = $1
    sleep 0.1
    get "/cache/"
    last_response.body =~ /nocache:(.+?)\n/
    b = $1
    assert_not_equal a,b
    
    # test cache is working
    get "/cache/"
    last_response.body =~ /\ncache:(.+?)\n/
    a = $1
    sleep 0.1
    get "/cache/"
    last_response.body =~ /\ncache:(.+?)\n/
    b = $1
    assert_equal a,b
    sleep 2
    get "/cache/"
    last_response.body =~ /\ncache:(.+?)\n/
    c = $1
    assert_not_equal a,c
    
    # test cache is not working for different url
    get "/cache?1"
    last_response.body =~ /\ncache:(.+?)\n/
    a = $1
    sleep 0.1
    get "/cache?2"
    last_response.body =~ /\ncache:(.+?)\n/
    a = $1
    assert_not_equal a,b
  end
end
