require 'jcode'

module Egalite

class NonEscapeString < String
  def +(b)
    b.is_a?(NonEscapeString) ? NonEscapeString.new(super(b)) : super(b)
  end
end

class HTMLTemplate
  RE_GROUP = /<group\s+name=['"](.+?)['"]>/i
  RE_ENDGROUP = /<\/group>/i
  RE_IF = /<if\s+name=['"](.+?)['"]>/i
  RE_ENDIF = /<\/if>/i
  RE_UNLESS = /<unless\s+name=['"](.+?)['"]>/i
  RE_ENDUNLESS = /<\/unless>/i
  RE_PLACE = /&=([-_0-9a-zA-Z]+?);/
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
  
  def escapeHTML(s)
    s.to_s.gsub(/&/n, '&amp;').gsub(/'/n,'&#039;').gsub(/\"/n, '&quot;').gsub(/>/n, '&gt;').gsub(/</n, '&lt;')
  end
  
  def handleNestedTag(html) # cut after endgroup tag
    while md1 = RE_GROUP.match(html)
      break if (RE_ENDGROUP.match(md1.pre_match))
      html = handleNestedTag(md1.post_match)
    end
    RE_ENDGROUP.match(html).post_match
  end

  def handleTemplate(html,orig_values)
    params = lambda { |k| orig_values[k] || orig_values[k.to_sym] }
    
    # parse group tag and recurse inner loop
    while md1 = RE_GROUP.match(html) # beware: complicated....
      break if (RE_ENDGROUP.match(md1.pre_match))
      groupval = params[md1[1]]
      groupval = [] if (groupval == nil)
      groupval = [groupval] unless (groupval.is_a?(Array))
      innertext = ""
      post = handleNestedTag(md1.post_match)
      groupval.each { |v| innertext << handleTemplate(md1.post_match,v) }
      # replace this group tag
      html[md1.begin(0),html.length] = innertext + post
    end
    # cut after end tag
    md1 = RE_ENDGROUP.match(html)
    html = md1.pre_match if (md1)

    # parse <if> tag (nested tag is not supported.)
    while md1 = RE_IF.match(html)
      pmd = params[md1[1]]
      unless pmd.blank?
        html.sub!(RE_IF,"")
        html.sub!(RE_ENDIF,"")
      else
        md2 = RE_ENDIF.match(html)
        html[md1.begin(0),md2.end(0) - md1.begin(0)] = ""
      end
    end
    while md1 = RE_UNLESS.match(html)
      pmd = params[md1[1]]
      if pmd.blank?
        html.sub!(RE_UNLESS,"")
        html.sub!(RE_ENDUNLESS,"")
      else
        md2 = RE_ENDUNLESS.match(html)
        html[md1.begin(0),md2.end(0) - md1.begin(0)] = ""
      end
    end

    # parse place holder
    html.gsub!(RE_PLACE) {
      key = $1
      if not params[key] and orig_values.respond_to?(key)
        orig_values.send(key)
      elsif params[key].is_a?(NonEscapeString) or not @default_escape
        params[key]
      else
        escapeHTML(params[key])
      end
    }
    
    # parse input tag type=text
    html.gsub!(RE_INPUT) { |s|
      attrs = parse_tag_attributes($1)
      next s if attrs['value'] || attrs['checked'] || attrs['selected']
      name = attrs['name']
      next s unless name
      case attrs['type']
        when 'text'
         s.sub!(/\/?>$/," value='"+escapeHTML(params[name])+"'/>") if params[name]
        when 'radio'
          s.sub!(/\/?>$/," checked/>") if (params[name] == attrs['value'])
        when 'checkbox'
          s.sub!(/\/?>$/," checked/>") if params[name]
      end
      s
    }

    # link tag
    html.gsub!(RE_A) { |s|
      attrs = parse_tag_attributes($1)
      next s if attrs['href']
      
      (colons, noncolons) = attr_colon(attrs)
      colons = StringifyHash.create(colons)
      link = @controller.url_for(colons)
      "<a href='#{link}' #{noncolons}>"
    }
    html.gsub!(RE_FORM) { |s|
      attrs = parse_tag_attributes($1)
      
      (colons, noncolons) = attr_colon(attrs)
      colons = StringifyHash.create(colons)
      link = @controller.url_for(colons)
      "<form action='#{link}' #{noncolons}>"
    }

    # parse select tag
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

    # parse include tag
    if block_given?
      html.gsub!(RE_INCLUDE) {
        attrs = parse_tag_attributes($1)
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
end

end # end module
