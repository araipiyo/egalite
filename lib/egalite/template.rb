module Egalite

class NonEscapeString < String
  def +(b)
    NonEscapeString.new(super(HTMLTagBuilder.escape_html(b)))
  end
end

class HTMLTemplate
  RE_NEST = /<(group|if|unless)\s+name=['"](.+?)['"]>/i
  RE_ENDNEST = /<\/(group|if|unless)>/i
  RE_PLACE = /&=([.-_0-9a-zA-Z]+?);/
  RE_INPUT = /<input\s+(.+?)>/im
  RE_SELECT = /<select\s+name\s*=\s*['"](.+?)['"](.*?)>\s*<\/select>/im
  
  RE_A = /<a\s+(.+?)>/im
  RE_FORM = /<form\s+(.+?)>/im

  RE_INCLUDE = /<include\s+(.+?)\/>/i
  RE_PARENT = /<parent\s+name=['"](.+?)['"]\s*\/>/i
  RE_YIELD = /<yield\/>/i
  
  attr_accessor :controller, :default_escape
  
  def initialize
    @default_escape = true
    @controller = nil
  end
  
  private
  
  def parse_tag_attributes(attrs)
    a = attrs.split(/(\:?\w+(!:[^=])|\:?\w+=(?:'[^']+'|"[^"]+"|\S+))\s*/)
    a = a.select { |s| s != "" }
    hash = {}
    a.each { |s|
      b = s.split('=',2)
      b[0].sub!(/\s$/,'')
      b[1] = b[1][1..-2] if b[1] and (b[1][0,1] == '"' or b[1][0,1] == "'")
      hash[b[0]] = b[1] || true
    }
    hash
  end
  def attr_colon(attrs)
    colons = {}
    attrs.each { |k,v| colons[k[1..-1]] = v if k =~ /^\:/ }
    str = attrs.select { |k,v| k !~ /^\:/ }.map { |k,v| "#{k}='#{v}'" }.join(' ')
    [colons, str]
  end
  
  def dotchain(values, name)
    dots = name.split('.').select {|s| not s.empty? }
    
    value = values
    dots.each { |key|
      value = if not value.is_a?(Hash) and value.respond_to?(key)
        value.send(key)
      elsif value.respond_to?(:[])
        value[key] || value[key.to_sym]
      end
      break unless value
    }
    value
  end

  #
  # tags
  #
  def placeholder(html, params)
    html.gsub!(RE_PLACE) {
      key = $1
      if params[key].is_a?(NonEscapeString) or not @default_escape
        params[key]
      else
        escapeHTML(params[key])
      end
    }
  end
  def input_tag(html, params)
    html.gsub!(RE_INPUT) { |s|
      attrs = parse_tag_attributes($1)
      next s if attrs['checked'] or attrs['selected']
      name = attrs['name']
      next s unless name
      case attrs['type']
        when 'text'
         next s if attrs['value']
         s.sub!(/\/?>$/," value='"+escapeHTML(params[name])+"'/>") if params[name]
        when 'hidden'
         next s if attrs['value']
         s.sub!(/\/?>$/," value='"+escapeHTML(params[name])+"'/>") if params[name]
        when 'radio'
          s.sub!(/\/?>$/," checked/>") if (params[name].to_s == attrs['value'])
        when 'checkbox'
          s.sub!(/\/?>$/," checked/>") if params[name]
      end
      s
    }
  end
  def a_tag(html, params)
    html.gsub!(RE_A) { |s|
      attrs = parse_tag_attributes($1)
      next s if attrs['href']
      next s unless @controller
      
      (colons, noncolons) = attr_colon(attrs)
      next s if colons.empty?
      # when :hoge=$foo, expand hash parameter ['foo']
      colons.each { |k,v|
        next if v[0,1] != '$'
        val = params[v[1..-1]]
        colons[k] = val
      }
      colons = StringifyHash.create(colons)
      link = @controller.url_for(colons)
      "<a href='#{link}' #{noncolons}>"
    }
  end
  def form_tag(html,params)
    html.gsub!(RE_FORM) { |s|
      attrs = parse_tag_attributes($1)
      next s if attrs['action']
      next s unless @controller
      
      (colons, noncolons) = attr_colon(attrs)
      next s if colons.empty?
      colons = StringifyHash.create(colons)
      link = @controller.url_for(colons)
      "<form action='#{link}' #{noncolons}>"
    }
  end
  def select_tag(html,params)
    html.gsub!(RE_SELECT) { sel = "<select name='#$1'#$2>"
      if (params[$1] and params[$1].is_a?(Array))
        params[$1].each_index() { |key|
          next if (key == 0)
          selected = " selected" if params[$1][0] == key
          value = params[$1][key]
          sel << "<option value='#{key}'#{selected}>"
          sel << escapeHTML(value)
          sel << "</option>" unless @keitai
        }
      end
      sel << "</select>"
    }
  end
  
  #
  # main routines
  #
  
  def nonnestedtags(html, params)
    placeholder(html,params)
    input_tag(html,params)
    a_tag(html,params)
    form_tag(html,params)
    select_tag(html,params)

    # parse include tag
    if block_given?
      html.gsub!(RE_INCLUDE) {
        attrs = parse_tag_attributes($1)
        attrs.each { |k,v| attrs[k[1..-1]] = v if k =~ /^\:/ }
        yield(attrs)
      }
      parent = nil
      md = RE_PARENT.match(html)
      parent = md[1] if md
      html.gsub!(RE_PARENT,"")
      if parent
        txt = yield(parent)
        txt.gsub!(RE_YIELD, html)
        html = txt
      end
    end
    html
  end

  def keyexpander(params, parent_params)
    lambda { |k|
      if k[0,1] == '.'
        dotchain(params, k)
      else
        if params[k] == nil
          if params[k.to_sym] == nil
            parent_params[k]
          else
            params[k.to_sym]
          end
        else
          params[k]
        end
      end
    }
  end

  def string_after_outermost_closetag(html)
    while md1 = RE_NEST.match(html)
      break if (RE_ENDNEST.match(md1.pre_match))
      html = string_after_outermost_closetag(md1.post_match)
    end
    RE_ENDNEST.match(html).post_match
  end
  
  public
  
  def escapeHTML(s)
    s.to_s.gsub(/&/n, '&amp;').gsub(/'/n,'&#039;').gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
  end
  
  def handleTemplate(html, orig_values, parent_params={}, &block)
    params = keyexpander(orig_values, parent_params)
    
    # parse group tag and recurse inner loop
    while md1 = RE_NEST.match(html) # beware: complicated....
      # break if it is innermost loop.
      break if (RE_ENDNEST.match(md1.pre_match))

      # obtain a length of outermost group tag.
      post = string_after_outermost_closetag(md1.post_match)
      
      tag = md1[1]
      key = md1[2]
      
      # recursive-call for each element of array
      innertext = ""
      case tag.downcase
        when 'group'
          groupval = params[key]
          groupval = [] if (groupval == nil)
          groupval = [groupval] unless (groupval.is_a?(Array))
          groupval.each { |v| 
            innertext << handleTemplate(md1.post_match, v, params)
          }
        when 'if'
          unless params[key].blank?
            innertext << handleTemplate(md1.post_match, orig_values, parent_params)
          end
        when 'unless'
          if params[key].blank?
            innertext << handleTemplate(md1.post_match, orig_values, parent_params)
          end
        else
          raise
      end
      # replace this group tag
      html[md1.begin(0)..-(post.size+1)] = innertext
    end
    # cutoff after end tag, in inner-most loop.
    md1 = RE_ENDNEST.match(html)
    html = md1.pre_match if (md1)

    nonnestedtags(html, params, &block)
  end
end

class CSRFTemplate < HTMLTemplate
  RE_FORM = /<form\s+([^>]+?)>(?!\s*<input type='hidden' name='csrf')/im

  def form_tag(html,params)
    html.gsub!(RE_FORM) { |s|
      formtag = s
      attrs = parse_tag_attributes($1)
      csrf = nil
      if attrs[":nocsrf"]
        attrs.delete(":nocsrf")
      elsif attrs["method"].upcase == "POST"
        csrf = params["csrf"]
        csrf = "<input type='hidden' name='csrf' value='#{escapeHTML(csrf)}'/>"
      end
      
      if (not attrs['action']) and @controller
        (colons, noncolons) = attr_colon(attrs)
        unless colons.empty?
          colons = StringifyHash.create(colons)
          link = @controller.url_for(colons)
          formtag = "<form action='#{link}' #{noncolons}>"
        end
      end
      "#{formtag}#{csrf}"
    }
  end
end

end # end module
