
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
    unless keys.size == header.size
      raise ArgumentError, "key and header count mismatch"
    end

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
  def raw(s)
    NonEscapeString.new(s)
  end

 public # export just for testing

  def opt(opts)
    opts.map { |k,v|
      next "" if [:default,:checked,:selected, :nil].member?(k)
      " #{escape_html(k)}='#{escape_html(v)}'"
    }.join
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
  def _text(value, name, opts)
    value = " value='#{escape_html(value)}'" if value
    opts[:size] = 30 unless opts[:size]
    raw "<input type='text' name='#{expand_name(name)}'#{value}#{opt(opts)}/>"
  end
  def text(name, opts = {})
    _text(@data[name] || opts[:default], name, opts)
  end
  def timestamp_text(name, opts = {})
    # todo: enable locale
    # todo: could unify to text()
    value = @data[name] || opts[:default]
    value = value.strftime('%Y-%m-%d %H:%M:%S')
    _text(value,name,opts)
  end
  def password(name, opts = {})
    value = @data[name] || opts[:default]
    value = " value='#{escape_html(value)}'" if value
    raw "<input type='password' name='#{expand_name(name)}'#{value}#{opt(opts)}/>"
  end
  def checkbox(name, value=nil, opts = {})
    checked = (@data[name] || opts[:default] || opts[:checked]) ? " checked='checked'" : ''
    checked = '' if @data[name] == false
    value ||= "true"
    value = " value='#{escape_html(value)}'"
    
    name = expand_name(name)
    
    ucv = opts[:uncheckedvalue]
    ucv ||= "false"
    hidden = "<input type='hidden' name='#{name}' value='#{escape_html(ucv)}'/>"
    hidden = "" if opts[:nohidden]
    
    raw "#{hidden}<input type='checkbox' name='#{name}'#{value}#{checked}#{opt(opts)}/>"
  end
  def radio(name, choice, opts = {})
    selected = (@data[name] == choice)
    selected = (opts[:default] == choice) || opts[:selected] if @data[name] == nil
    selected = selected ? " selected='selected'" : ''
    
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
  def select_by_association(name, options, optname, opts = {})
    idname = (opts[:idname] || "id").to_sym
    optionstr = options.map {|o|
      flag = o[idname] == @data[name]
      selected = flag ? " selected='selected'" : ""
      "<option value='#{o[idname]}'#{selected}>#{o[optname]}</option>"
    }.join('')
    
    if opts[:nil]
      selected = (@data[name] == nil) ? "selected='selected'" : ''
      optionstr = "<option value='' #{selected}>#{opts[:nil]}</option>" + optionstr
    end
    
    raw "<select name='#{expand_name(name)}'#{opt(opts)}>#{optionstr}</select>"
  end
end

end
