#!ruby -Ku

$KCODE='utf8'

require 'rubygems'
require 'egalite'

ShowException = true
RouteDebug = false
egalite = Egalite::Handler.new

run egalite

