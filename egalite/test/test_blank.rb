$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'test/unit'
require 'blank'

class Empty
  def empty?
    true
  end
end

class T_Blank < Test::Unit::TestCase
  def test_nil
    assert nil.blank?
  end
  def test_false
    assert false.blank?
  end
  def test_true
    assert(true.blank? == false)
  end
  def test_array
    assert [].blank?
    assert([1,2,3].blank? == false)
  end
  def test_hash
    assert({}.blank?)
    assert({:foo => 1}.blank? == false)
  end
  def test_empty
    assert Empty.new.blank?
  end
  def test_string
    assert "".blank?
    assert " \t\n".blank?
    assert("hoge".blank? == false)
  end
  def test_numeric
    assert(123.blank? == false)
  end
  def test_object
    assert(:foo.blank? == false)
  end
end
