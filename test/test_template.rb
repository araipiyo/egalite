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
      :false => false,
      :array => [
        {:val => 1,
         :true => true,
         :array2 => [{:val => 2}],
         :array3 => [{:val => 3, :array4 => [{:val => 41},{:val => 42}]
         }]
        },
        {:val => 12}
      ]
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

class T_Template < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new(:template_path => File.dirname(__FILE__))
  end
  def test_template
    get "/template"
#    puts last_response.body
    assert last_response.ok?
    assert last_response.body =~ /value:piyo/
    assert last_response.body =~ /nestedif/
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
  def test_grouptag
    get "/template"
    assert last_response.body =~ /group1-1: 1/
    assert last_response.body =~ /group1-2: 1/
    assert last_response.body =~ /group1-1: 12/
    assert last_response.body =~ /group1-2: 12/
    assert last_response.body =~ /group2: 2/
    assert last_response.body =~ /group3-1: 3/
    assert last_response.body =~ /group3-2: 3/
    assert last_response.body =~ /group4: 41/
    assert last_response.body =~ /group4: 42/
  end
end

class T_OnHtmlLoadFilter < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Egalite::Handler.new(
      :template_path => File.dirname(__FILE__),
      :filter_on_html_load => lambda { |html| "filtered: #{html}" }
    )
  end
  def test_filter_on_html_load
    get "/template"
    assert last_response.ok?
    assert last_response.body =~ /\Afiltered: <html>/
    assert last_response.body =~ /value:piyo/
    assert last_response.body =~ /nestedif/
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
