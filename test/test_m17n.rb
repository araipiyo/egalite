$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'
require 'm17n'

require 'rack/test'

require 'setup'

class FrenchController < Egalite::Controller
  include Egalite::M17N::Filters

  def get
    {:g => [:text => 'Do you speak English?']}
  end
  def langcode
    @lang.langcode
  end
  def dlg
    delegate(:action => :msg, :message => 'I am an English man.')
  end
  def msg
    {:message => params[:message]}
  end
end

class T_Translation < Test::Unit::TestCase
  include Rack::Test::Methods

  def setup
    Egalite::M17N::Translation.load(File.join(File.dirname(__FILE__),'m17n.txt'))
    Egalite::M17N::Translation.allow_content_negotiation = true
    Egalite::M17N::Translation.user_default_lang = 'en'
  end
  def app
    Egalite::Handler.new(:template_path => File.dirname(__FILE__))
  end
  def test_translation
    # English
    get "/french"
    assert last_response.ok?
    assert_no_match /Parlez vous Francais\?/, last_response.body
    assert_match  /Do you speak English\?/, last_response.body
    assert_no_match /Prix/, last_response.body
    assert_match  /Price/, last_response.body
    assert_no_match /Nom de Produit/, last_response.body
    assert_match  /Product Name/, last_response.body
    assert_no_match %r|/hoge/itembtn1_fr.jpg|, last_response.body
    assert_match %r|/hoge/itembtn1.jpg|, last_response.body

    # French
    get "/french", {}, {'HTTP_ACCEPT_LANGUAGE' => 'ja,fr;q=0.8,en'}
    assert last_response.ok?
    assert_match /Parlez vous Francais\?/, last_response.body
    assert_no_match  /Do you speak English\?/, last_response.body
    assert_match /Prix/, last_response.body
    assert_no_match  /Price/, last_response.body
    assert_match /Nom de Produit/, last_response.body
    assert_no_match  /Product Name/, last_response.body
    assert_match %r|/hoge/itembtn1_fr.jpg|, last_response.body
    assert_no_match %r|/hoge/itembtn1.jpg|, last_response.body
  end
  def test_translationmsg
    # English
    get "/french/dlg"
    assert last_response.ok?
    assert_no_match  /@@@Je suis un Francais\.@@@/, last_response.body
    assert_match  /I am an English man\./, last_response.body
    
    get "/french/dlg", {}, {'HTTP_ACCEPT_LANGUAGE' => 'en,fr;q=0.8'}
    assert last_response.ok?
    assert_no_match  /@@@Je suis un Francais\.@@@/, last_response.body
    assert_match  /I am an English man\./, last_response.body
    get "/french/dlg", {}, {'HTTP_ACCEPT_LANGUAGE' => 'fr', 'HTTP_HOST' => 'en.example.com'}
    
    assert last_response.ok?
    assert_no_match  /@@@Je suis un Francais\.@@@/, last_response.body
    assert_match  /I am an English man\./, last_response.body
    
    # French
    get "/french/dlg", {}, {'HTTP_ACCEPT_LANGUAGE' => 'ja,fr;q=0.8,en'}
    assert_match  /@@@Je suis un Francais\.@@@/, last_response.body
    assert_no_match  /I am an English man\./, last_response.body

    get "/french/dlg", {}, {'HTTP_HOST' => 'fr.example.com'}
    assert_match  /@@@Je suis un Francais\.@@@/, last_response.body
    assert_no_match  /I am an English man\./, last_response.body

    get "/french/dlg", {}, {'HTTP_ACCEPT_LANGUAGE' => 'zh-hans-cn'}
    assert_match  /@@@Je suis un Francais\.@@@/, last_response.body
    assert_no_match  /I am an English man\./, last_response.body

    get "/french/dlg", {}, {'HTTP_ACCEPT_LANGUAGE' => 'fr-fr'}
    assert_match  /@@@Je suis un Francais\.@@@/, last_response.body
    assert_no_match  /I am an English man\./, last_response.body
  end
  def test_langcode
    get "/french/langcode"
    assert last_response.ok?
    assert_equal "en", last_response.body

    get "/french/langcode", {}, {'HTTP_HOST' => 'fr.example.com'}
    assert last_response.ok?
    assert_equal "fr", last_response.body

    get "/french/langcode", {}, {'HTTP_HOST' => 'zh-hans-cn.example.com'}
    assert last_response.ok?
    assert_equal "fr", last_response.body
  end
end

