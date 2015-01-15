$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'lib/egalite'

require 'rack'
require 'rack/multipart'
require 'rack/test'

require 'setup'

class ErrorLoggerController < Egalite::Controller
  def foo
    Egalite::ErrorLogger.catch_exception(true) {
      raise "piyolog"
    }
    "hoge"
  end
end

class T_ErrorLogger < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    db = Sequel.sqlite
    @db = db
    Egalite::ErrorLogger.create_table(db)
    Egalite::Handler.new({
      :admin_emails => "to@example.com",
      :email_from => "from@example.com",
      :exception_log_table => :logs,
      :db => db,
    })
  end
  def test_errortemplate
    Sendmail.mock = true
    get "/error/logger/foo"
    assert last_response.ok?
    assert_equal "hoge", last_response.body
    assert_equal "from@example.com", Sendmail.lastmail[1]
    assert_match /piyolog/, Sendmail.lastmail[0]
    assert_match /piyolog/, @db[:logs].first[:text]
  end
end
