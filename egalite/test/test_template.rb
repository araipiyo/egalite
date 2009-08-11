$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'

require 'rack/test'

ShowException = true
RouteDebug = false

class TemplateController < Egalite::Controller
  def get
    {
      :val => 'piyo',
      :true => true,
      :false => false
    }
  end
end

class T_Handler < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new(:template_path => File.dirname(__FILE__))
  end
  def test_template
    get "/template"
    assert last_response.ok?
    assert last_response.body =~ /value:piyo/
    assert last_response.body =~ /iftrue/
    assert last_response.body !~ /iffalse/
    assert last_response.body !~ /unlesstrue/
    assert last_response.body =~ /unlessfalse/
    assert last_response.body =~ %r|<a\s+href='/foo/bar/1\?hoge=piyo'\s*>|
    assert last_response.body =~ %r|<form action='/foo/bar/1\?hoge=piyo'\s+method='post'\s*>|
  end
end
