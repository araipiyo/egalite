$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'

require 'rack/test'

require 'setup'

class CsrftemplateController < Egalite::CSRFController
  def get
    @template_file = 'template.html'
    session.create(:user_id => 1)
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
    @template_file = 'template_inner.html'
    { :innervalue => 'mogura' }
  end
  def innerparam(id)
    @template_file = 'template_innerparam.html'
    { :innervalue => "inner:#{id}_#{params[:usagi]}" }
  end
  def innerdelegate
    delegate :action => :innerparam, :id => 5, :usagi => :kirin
  end
end

class T_CSRFTemplate < Test::Unit::TestCase
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
      :template_path => File.dirname(__FILE__),
      :template_engine => Egalite::CSRFTemplate
    )
  end
  def test_template
    get "/csrftemplate"
    assert last_response.ok?
    assert last_response.body =~ /value:piyo/
    assert last_response.body =~ /nestedif/
    assert last_response.body =~ /iftrue/
    assert last_response.body !~ /iffalse/
    assert last_response.body !~ /unlesstrue/
    assert last_response.body =~ /unlessfalse/
    assert last_response.body =~ %r|<a\s+href='/foo/bar/1\?hoge=piyo'\s*>|
    assert last_response.body =~ %r|<form action='/foo/bar/1\?hoge=piyo'\s+method='post'\s*><input type='hidden' name='csrf' value='[0-9]+_[0-9a-f]+'/>|
    assert last_response.body =~ /mogura/
    assert last_response.body =~ /inner:9_hiyoko/
    assert last_response.body =~ /inner:5_kirin/
  end
  def test_grouptag
    get "/csrftemplate"
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

