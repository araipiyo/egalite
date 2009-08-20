$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'
require 'rexml/xpath'
require 'rexml/document'


class T_StringifyHash < Test::Unit::TestCase
  include Egalite

  def setup
    @target = StringifyHash.new
  end

  def test_key_set_should_assume_symbol_as_string

    @target[:key] = 10
    assert_equal(@target["key"], 10)
  end

  def test_key_get_should_assume_symbol_as_string
    @target["key"] = 10
    assert_equal(@target[:key], 10)
  end

  def test_key_p_should_assume_symbol_as_string
    @target["key"] = 10
    assert(@target.key?(:key))
  end

  def test_update_should_assume_symbol_as_string
    @target.update({:key => 10})
    assert(@target.key?("key"))
  end

  def test_fetch_should_be_ok
    @target["key"] = 10
    assert_equal(@target.fetch(:key), 10)
  end

  def test_values_at_should_be_ok
    @target["key1"] = 10
    @target["key2"] = 20
    assert_equal([10, 20], @target.values_at(:key1, :key2))
  end

  def test_dup_should_create_new_one
    another = @target.dup
    assert_equal(another, @target)
    assert_equal(another.class, StringifyHash)
    another["hoge"] = "ika"
    assert(another != @target) # should be different instance
  end

  def test_dup_should_create_new_hash
    another = @target.to_hash
    assert_equal(another.class, Hash)
    another["hoge"] = "ika"
    assert(another != @target) # should be different instance
  end
end

# XXX: test form
# XXX: test expand_name
