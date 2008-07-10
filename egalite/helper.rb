
module Egalite

class TableHelper
 private
  def self.opt(opts)
    opts.map { |k,v| " #{escape_html(k)}='#{escape_html(v)}'" }.join
  end
  def self.escape_html(s)
    s.is_a?(NonEscapeString) ? s : Rack::Utils.escape_html(s)
  end
  def self._table(header, content, table_opts)
    head = ""
    if header
      head = header.map {|s| "<th>#{escape_html(s)}</th>" }.join
      head = "  <tr>#{head}</tr>\n"
    end
    body = content.map { |line| "  <tr>#{yield(line)}</tr>\n" }
    NonEscapeString.new("<table#{opt(table_opts)}>\n#{head}#{body}</table>")
  end
 public
  def self.table_by_hash(keys, header, content, table_opts = {})
    _table(header, content, table_opts) { |line|
      keys.map { |key| "<td>#{escape_html(line[key])}</td>"}.join
    }
  end
  def self.table_by_array(header, content, table_opts = {})
    _table(header, content, table_opts) { |line|
      line.map { |s| "<td>#{escape_html(s)}</td>" }.join
    }
  end
end

class FormHelper
 private
  def escape_html(s)
    Rack::Utils.escape_html(s)
  end
  def expand_name(s)
    s = "#{@param_name}[#{s}]" if @param_name
    escape_html(s)
  end
  def opt(opts)
    opts.map { |k,v|
      next "" if [:default,:checked,:selected].member?(k)
      " #{escape_html(k)}='#{escape_html(v)}'"
    }.join
  end
  def raw(s)
    NonEscapeString.new(s)
  end

 public
  def initialize(data = {}, param_name = nil, opts = {})
    @data = data
    @param_name = param_name
    @form_opts = opts
  end
  def form(method, url=nil)
    action = url ? " action='#{escape_html(url)}'" : ''
    raw "<form method='#{escape_html(method)}'#{action}#{opt(@form_opts)}>"
  end
  def text(name, opts = {})
    value = @data[name] || opts[:default]
    value = " value='#{escape_html(value)}'" if value
    raw "<input type='text' name='#{expand_name(name)}'#{value}#{opt(opts)}/>"
  end
  def password(name, opts = {})
    value = @data[name] || opts[:default]
    value = " value='#{escape_html(value)}'" if value
    raw "<input type='password' name='#{expand_name(name)}'#{value}#{opt(opts)}/>"
  end
  def checkbox(name, value=nil, opts = {})
    checked = (@data[name] || opts[:default] || opts[:checked]) ? " checked" : ''
    checked = '' if @data[name] == false
    value ||= "true"
    value = " value='#{value}'"
    name = expand_name(name)
    raw "<input type='checkbox' name='#{name}'#{value}#{checked}#{opt(opts)}/>"
  end
  def radio(name, choice, opts = {})
    selected = (@data[name] == choice)
    selected = (opts[:default] == choice) || opts[:selected] if @data[name] == nil
    selected = selected ? " selected" : ''
    
    n = expand_name(name)
    c = escape_html(choice)
    raw "<input type='radio' name='#{n}' value='#{c}'#{selected}#{opt(opts)}/>"
  end
  def textarea(name, opts = {})
    value = escape_html(@data[name] || opts[:default])
    raw "<textarea name='#{expand_name(name)}'#{opt(opts)}>#{value}</textarea>"
  end
  def file(name, opts = {})
    raw "<input type='file' name='#{expand_name(name)}'#{opt(opts)}/>"
  end
  def submit(value = nil, name = nil, opts = {})
    name = " name='#{expand_name(name)}'" if name
    value = " value='#{escape_html(value)}'" if value
    raw "<input type='submit'#{name}#{value}#{opt(opts)}/>"
  end
  def image
  end
  def select
    # どういうパターンを実装するか？
  end
end

end
