$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << File.join(File.dirname(__FILE__), '..')

require 'rubygems'
require 'test/unit'
require 'egalite'
require 'rexml/xpath'
require 'rexml/document'

module XPathTestingHelper

  def to_doc(text)
    REXML::Document.new(StringIO.new(text))
  end

  def assert_xpath_match_count(exp, n, doc)
    assert_equal(n, REXML::XPath::match(doc, exp).size)
  end

  def X(doc, exp)
    doc = to_doc(doc) unless doc.kind_of?(REXML::Document)
    REXML::XPath::match(doc, exp)
  end

  def X1(doc, exp)
    doc = to_doc(doc) unless doc.kind_of?(REXML::Document)
    REXML::XPath::first(doc, exp)
  end

end

class T_TableHelper < Test::Unit::TestCase
  include Egalite
  include XPathTestingHelper

  def make_hash_content(n=1)
    [{
      :foo => "Foo",
      :bar => "Bar",
      :baz => "Baz",
      :ika => "Ika",
    }]*n
  end

  def make_array_content(n=1)
    [["Foo", "Bar", "Baz"]]*n
  end

  def make_header
    ["header1", "header2", "header3"]
  end

  def test_table_by_hash_hello
    table = to_doc(TableHelper.table_by_hash([:foo, :bar, :baz], 
                                             make_header,
                                             make_hash_content))
    assert_xpath_match_count("/table", 1, table) 
    assert_xpath_match_count("/table/tr", 2, table) 
    assert_xpath_match_count("/table/tr/th", 3, table) 
    assert_xpath_match_count("/table/tr/td", 3, table) 
  end

  def test_table_by_hash_table_opts_should_appear_as_attribute
    table = to_doc(TableHelper.table_by_hash([], [], [],
                                             {"foo_attr"=>"foo_value"}))
    t = X1(table, "/table")
    assert_equal("foo_value", t.attributes["foo_attr"])
  end

  def test_table_by_hash_should_raise_if_header_content_mismatch
    assert_raise(ArgumentError) do
      TableHelper.table_by_hash([:foo, :bar], 
                                make_header,
                                make_hash_content)
    end
  end

  def test_table_by_hash_should_handle_multiple_rows
    count = 3
    table = to_doc(TableHelper.table_by_hash([:foo, :bar, :baz], 
                                             make_header,
                                             make_hash_content(count)))
    assert_xpath_match_count("/table/tr", 1 + count, table) # + 1 for header <tr>
  end

  def test_table_by_hash_should_show_empty_cell_for_nonexist_key
    table = to_doc(TableHelper.table_by_hash([:foo, :bar, :notexist], 
                                             make_header,
                                             make_hash_content))
    assert_nil(REXML::XPath::match(table, "/table/tr/td").map{ |i| i.text }[2])
  end

  def test_table_by_array_hello
    table = to_doc(TableHelper.table_by_array(make_header,
                                              make_array_content))
    assert_xpath_match_count("/table/tr", 2, table) 
    assert_xpath_match_count("/table/tr/th", 3, table) 
    assert_xpath_match_count("/table/tr/td", 3, table) 

    assert_equal(2, X(table, "/table/tr").size)
    assert_equal(3, X(table, "/table/tr/th").size)
    assert_equal(3, X(table, "/table/tr/td").size)
  end

end

class T_FormHelper < Test::Unit::TestCase
  include Egalite
  include XPathTestingHelper

  def test_should_instantiatable
    FormHelper.new({})
  end

  def test_form_hello
    action = "/action"
    f = FormHelper.new({:foo => "Foo"})
    i = X(f.form(:GET, action) + f.close, "/form")
    assert_equal(i.size, 1)
    assert_equal("GET", i[0].attributes["method"])
    assert_equal(action, i[0].attributes["action"])
  end

  def test_form_should_allow_nil_action
    f = FormHelper.new({:foo => "Foo"})
    i = X1(f.form(:GET) + f.close, "/form")
    assert_equal(nil, i.attributes["action"])
  end

  def test_text_should_result_text_input
    f = FormHelper.new({:foo => "Foo"})
    i = X1(f.text(:foo), "/input")
    assert_equal("Foo", i.attributes["value"])
    assert_equal("text", i.attributes["type"])
    assert_equal("foo", i.attributes["name"])
  end

  def test_text_should_use_default_if_no_data
    f = FormHelper.new({:foo => "Foo"})
    i = X1(f.text(:bar, {:default => "Default"}), "/input")
    assert_equal("Default", i.attributes["value"])
    assert_equal("text",i.attributes["type"])
    assert_equal("bar", i.attributes["name"])
  end

  def test_text_timestamp_should_be_ok
    input    = "2009/01/02 12:30:45"
    expected = "2009-01-02 12:30:45"
    f = FormHelper.new({:foo => Time.parse(input)})
    i = X1(f.timestamp_text(:foo), "/input")
    assert_equal(expected, i.attributes["value"])
    assert_equal("text", i.attributes["type"])
    assert_equal("foo", i.attributes["name"])
  end

  def test_hidden_should_be_ok
    f = FormHelper.new({:foo => "Foo"})
    i = X1(f.hidden(:foo), "/input")
    assert_equal("Foo", i.attributes["value"])
    assert_equal("hidden", i.attributes["type"])
    assert_equal("foo", i.attributes["name"])
  end

  def test_password_should_be_ok
    f = FormHelper.new({:foo => "Foo"})
    i = X1(f.password(:foo), "/input")
    assert_equal("Foo", i.attributes["value"])
    assert_equal("password", i.attributes["type"])
    assert_equal("foo", i.attributes["name"])
  end

  def test_checkbox_should_be_checked_if_data_given
    f = FormHelper.new({:foo => "OK"})
    i = X1(f.checkbox(:foo, "Bar", :nohidden => true), "/input")
    assert_equal("Bar", i.attributes["value"])
    assert_equal("checked", i.attributes["checked"])
    assert_equal("foo", i.attributes["name"])
    assert_equal("checkbox", i.attributes["type"])
  end

  def test_checkbox_should_NOT_be_checked_unless_something_given
    f = FormHelper.new({:foo => "OK"})
    i = X1(f.checkbox(:bar, "Bar", :nohidden => true), "/input")
    assert_equal(nil, i.attributes["checked"])
  end

  def _test_checkbox_should_be_checked_if_opt_default_given(option_name)
    f = FormHelper.new({})
    i = X1(f.checkbox(:foo, "Bar", {option_name => 'OK', :nohidden => true}), "/input")
    assert_equal("checked", i.attributes["checked"])
    assert_equal("foo", i.attributes["name"])
  end

  def test_checkbox_should_be_checked_if_opt_default_given
    _test_checkbox_should_be_checked_if_opt_default_given(:default)
  end

  def test_checkbox_should_be_checked_if_opt_checked_given
    _test_checkbox_should_be_checked_if_opt_default_given(:checked)
  end

  def test_radio_should_be_ok
    f = FormHelper.new({:foo => "Foo"})
    i = X1(f.radio(:foo, "Foo"), "/input")
    assert_equal("Foo", i.attributes["value"])
    assert_equal("radio", i.attributes["type"])
    assert_equal("foo", i.attributes["name"])
    assert_equal("selected", i.attributes["selected"])
  end

  def test_radio_should_not_be_checked_if_choice_mismatch
    f = FormHelper.new({:bar => "Foo"})
    i = X1(f.radio(:foo, "Foo"), "/input")
    assert_equal("Foo", i.attributes["value"])
    assert_equal(nil, i.attributes["selected"])
  end

  def test_textarea_should_be_ok
    f = FormHelper.new({:foo => "Foo"})
    t = X(f.textarea(:foo), "/textarea")
    assert_equal(1, t.size)
    assert_equal("Foo", t[0].text)
  end

  def test_file_should_be_ok
    f = FormHelper.new({:foo => "Foo"})
    i = X1(f.file(:foo), "/input")
    assert_equal("file", i.attributes["type"])
    assert_equal("foo", i.attributes["name"])
  end

  def test_submit_should_be_ok
    f = FormHelper.new()
    i = X1(f.submit("foovalue", "fooname"), "/input")
    assert_equal("foovalue", i.attributes["value"])
    assert_equal("submit", i.attributes["type"])
    assert_equal("fooname", i.attributes["name"])
  end

  def test_select_by_array_array
    f = FormHelper.new()
    array = [[nil,nil],[1,:foo],[2,:bar]]
    d = to_doc(f.select_by_array("test", array))
    assert_equal(1, X(d, "/select").size)
    assert_equal("test", X(d, "/select")[0].attributes["name"])
    assert_equal(3, X(d, "/select/option").size)
    o0 = X(d, "/select/option")[0]
    assert_equal(nil, o0.text)
    assert_equal("", o0.attributes["value"])
    o1 = X(d, "/select/option")[1]
    assert_equal("foo", o1.text)
    assert_equal("1", o1.attributes["value"])
    o2 = X(d, "/select/option")[2]
    assert_equal("bar", o2.text)
    assert_equal("2", o2.attributes["value"])
  end

  def test_select_by_array_string
    f = FormHelper.new()
    array = [:foo,:bar]
    d = to_doc(f.select_by_array("test", array))
    assert_equal(1, X(d, "/select").size)
    assert_equal("test", X(d, "/select")[0].attributes["name"])
    assert_equal(2, X(d, "/select/option").size)
    o0 = X(d, "/select/option")[0]
    assert_equal("foo", o0.text)
    assert_equal("foo", o0.attributes["value"])
    o1 = X(d, "/select/option")[1]
    assert_equal("bar", o1.text)
    assert_equal("bar", o1.attributes["value"])
  end
  
  def make_select_options
    [{:optname => "optvalue0", :id=> "id0"},
     {:optname => "optvalue1", :id=> "id1"}]
  end

  def test_select_by_association_hello
    f = FormHelper.new()
    d = to_doc(f.select_by_association("Name", make_select_options, :optname))
    assert_equal(1, X(d, "/select").size)
    assert_equal(2, X(d, "/select/option").size)
    o0 = X(d, "/select/option")[0]
    assert_equal("optvalue0", o0.text)
    assert_equal("id0", o0.attributes["value"])
  end

  def test_select_by_association_should_add_option_if_nil_opt
    options = make_select_options
    niltext = "NILTEXT"
    f = FormHelper.new()
    d = to_doc(f.select_by_association("Name", options, :optname, {:nil => niltext}))
    assert_equal(1, X(d, "/select").size)
    assert_equal(options.size + 1, X(d, "/select/option").size)
    last = X1(d, "/select/option")
    assert_equal("", last.attributes["value"])
    assert_equal(niltext, last.text)
  end

  def make_opt_div(opts)
    f = FormHelper.new()
    "<div #{f.opt(opts)} />"
  end

  def test_opt_hello
    d = X1(to_doc(make_opt_div({:foo => "Foo", :bar => "Bar"})), "/div")
    assert_equal("Foo", d.attributes["foo"])
    assert_equal("Bar", d.attributes["bar"])
  end

  def _test_opt_should_skip_special_keys(key)
    opts = {:foo => "Foo"}
    opts[key] = "Val"
    d = X1(to_doc(make_opt_div(opts)), "/div")
    assert_equal("Foo", d.attributes["foo"])
    assert_equal(nil, d.attributes[key.to_s])
  end    

  def test_opt_should_skip_special_keys
    _test_opt_should_skip_special_keys(:default)
    _test_opt_should_skip_special_keys(:checked)
    _test_opt_should_skip_special_keys(:selected)
    _test_opt_should_skip_special_keys(:nil)
  end

end
