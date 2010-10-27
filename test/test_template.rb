$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'

require 'rack/test'

require 'setup'

class TemplateController < Egalite::Controller
  def get
    {
      :val => 'piyo',
      :true => true,
      :false => false
    }
  end
  def inner
    { :innervalue => 'mogura' }
  end
  def innerparam(id)
    { :innervalue => "inner:#{id}_#{params[:usagi]}" }
  end
  def innerdelegate
    delegate :action => :innerparam, :id => 5, :usagi => :kirin
  end
end

class T_Handler < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new(:template_path => File.dirname(__FILE__))
  end
  def test_template
    get "/template"
#    puts last_response.body
    assert last_response.ok?
    assert last_response.body =~ /value:piyo/
    assert last_response.body =~ /iftrue/
    assert last_response.body !~ /iffalse/
    assert last_response.body !~ /unlesstrue/
    assert last_response.body =~ /unlessfalse/
    assert last_response.body =~ %r|<a\s+href='/foo/bar/1\?hoge=piyo'\s*>|
    assert last_response.body =~ %r|<form action='/foo/bar/1\?hoge=piyo'\s+method='post'\s*>|
    assert last_response.body =~ /mogura/
    assert last_response.body =~ /inner:9_hiyoko/
    assert last_response.body =~ /inner:5_kirin/
  end
end
