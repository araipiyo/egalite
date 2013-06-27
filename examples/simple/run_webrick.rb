$:.unshift File.dirname(__FILE__) 

require 'example'

ShowException = true
RouteDebug = false
egalite = Egalite::Handler.new

Rack::Handler::WEBrick.run(egalite, :Port => 5000)

