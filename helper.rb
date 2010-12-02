
module Egalite

module HTMLTagBuilder
  def escape_html(s)
    s.is_a?(NonEscapeString) ? s : NonEscapeString.new(Rack::Utils.escape_html(s))
  end
  def tag(name , soc, attributes)
    close = soc == :close ? '/' : ''
    solo = soc == :solo ? '/' : ''
    
    atr = if attributes and not attributes.empty?
      s = attributes.map { |k,v| "#{escape_html(k)}='#{escape_html(v)}'" }.join(' ')
      " #{s}"
    else
      ""
    end
    NonEscapeString.new("<#{close}#{escape_html(name)}#{atr}#{solo}>")
  end
  def tag_solo(name, attributes)
    tag(name, :solo, attributes)
  end
  def tag_open(name, attributes)
    tag(name, :open, attributes)
  end
  def tag_close(name, attributes)
    tag(name, :close, attributes)
  end
  class <<self
    include Egalite::HTMLTagBuilder
    def a(url, s)
      tag_open('a', :href=>url) + escape_html(s) + tag_close('a', {})
    end
    def li(array)
      array.map{ |s| "<li>#{escape_html(s)}</li>" }.join("\n")
    end
    def ol(array)
      "<ol>#{li(array)}</ol>"
    end
    def ul(array)
      "<ul>#{li(array)}</ul>"
    end
  end
end

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
  include HTMLTagBuilder

 private
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
  def opt_as_hash(opts)
    o = opts.dup
    o.each_key { |k|
      o.delete(k) if [:default,:checked,:selected, :nil].member?(k)
    }
    o
  end

 public

  def initialize(data = {}, param_name = nil, opts = {})
    @data = data
    @param_name = param_name
    @form_opts = opts
  end
  def form(method, url=nil)
    attrs = opt_as_hash(@form_opts)
    attrs[:method] = method.to_s.upcase
    attrs[:action] = url if url
    tag_open(:form,attrs)
  end
  def close
    tag_close(:form,nil)
  end
  def _text(value, name, opts)
    attrs = opt_as_hash(opts)
    attrs[:value] = value if value
    attrs[:size] ||= 30
    attrs[:type] = 'text'
    attrs[:name] = expand_name(name)
    tag_solo(:input, attrs)
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
    attrs = opt_as_hash(opts)
    attrs[:value] = value if value
    attrs[:type] = "password"
    attrs[:name] = expand_name(name)
    tag_solo(:input,attrs)
  end
  def hidden(name, opts = {})
    value = @data[name] || opts[:default]
    attrs = opt_as_hash(opts)
    attrs[:value] = value if value
    attrs[:type] = "hidden"
    attrs[:name] = expand_name(name)
    tag_solo(:input,attrs)
  end
  def checkbox(name, value="true", opts = {})
    checked = (@data[name] || opts[:default] || opts[:checked])
    checked = false if @data[name] == false
    
    attr_cb = opt_as_hash(opts)
    attr_cb[:type] = 'checkbox'
    attr_cb[:name] = expand_name(name)
    attr_cb[:value] = value
    attr_cb[:checked] = "checked" if checked

    ucv = opts[:uncheckedvalue] || 'false'
    attr_h = {:type => 'hidden', :name => expand_name(name), :value => ucv}
    hidden = opts[:nohidden] ? '' : tag_solo(:input, attr_h)
    
    raw "#{hidden}#{tag_solo(:input, attr_cb)}"
  end
  def radio(name, choice, opts = {})
    selected = (@data[name] == choice)
    selected = (opts[:default] == choice) || opts[:selected] if @data[name] == nil
    
    attrs = opt_as_hash(opts)
    attrs[:selected] = 'selected' if selected
    attrs[:name] = expand_name(name)
    attrs[:value] = choice
    attrs[:type] = 'radio'
    
    tag_solo(:input, attrs)
  end
  def textarea(name, opts = {})
    value = escape_html(@data[name] || opts[:default])
    raw "<textarea name='#{expand_name(name)}'#{opt(opts)}>#{value}</textarea>"
  end
  def file(name, opts = {})
    attrs = opt_as_hash(opts)
    attrs[:name] = expand_name(name)
    attrs[:type] = 'file'
    tag_solo(:input, attrs)
  end
  def submit(value = nil, name = nil, opts = {})
    attrs = opt_as_hash(opts)
    attrs[:name] = expand_name(name) if name
    attrs[:value] = value if value
    attrs[:type] = 'submit'
    tag_solo(:input, attrs)
  end
  def image
  end
  def select_by_array(name, options, opts = {})
    optionstr = options.map {|o|
      flag = o[0] == @data[name]
      a = {:value => o[0]}
      a[:selected] = 'selected' if flag
      "#{tag_open(:option, a)}#{escape_html(o[1])}</option>"
    }.join('')
    
    raw "<select name='#{expand_name(name)}'#{opt(opts)}>#{optionstr}</select>"
  end
  def select_by_association(name, options, optname, opts = {})
    idname = (opts[:idname] || "id").to_sym
    optionstr = options.map {|o|
      flag = o[idname] == @data[name]
      a = {:value => o[idname]}
      a[:selected] = 'selected' if flag
      "#{tag_open(:option, a)}#{escape_html(o[optname])}</option>"
    }.join('')
    
    if opts[:nil]
      selected = (@data[name] == nil) ? "selected='selected'" : ''
      optionstr = "<option value='' #{selected}>#{escape_html(opts[:nil])}</option>" + optionstr
    end
    
    raw "<select name='#{expand_name(name)}'#{opt(opts)}>#{optionstr}</select>"
  end
end

end
