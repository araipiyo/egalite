
module Egalite
  module M17N
    
    
    module Filters
      def before_filter
        # check hostname first to determine which language to serve.
        first = req.host.split(/\./).first
        @lang = Translation.lang(first)
        if not @lang and req.accept_language and Translation.allow_content_negotiation
          # fallback to Accept-Language HTTP header for language to serve.
          langs = req.accept_language.split(/,/)
          @lang = langs.map { |s| Translation.lang(s.split(/;/).first) }.compact.first
        end
        @lang ||= Translation.lang(Translation.user_default_lang)
        @lang ||= Translation.lang('ja')
        req.language = @lang.langcode
        
        super
      end
      def filter_on_html_load(html,path)
        html = @lang.translate_html(path, html) if @lang
        super(html,path)
      end
      def after_filter_return_value(response)
        if @lang
          response = @lang.translate_msg(req.controller_class, req.action_method, response)
        end
        super(response)
      end
      def _(str, values = [])
        if @lang
          str = @lang.translate_string(req.controller_class, req.action_method, str, values)
        else
          str = str.dup
          values.each_with_index { |s2,i| str.gsub!(/\{#{i}\}/, s2) }
        end
        str
      end
    end
    class Controller < Egalite::Controller
      include Filters
    end
    
    
    class Translation
      class <<self
        attr_accessor :langs, :user_default_lang, :allow_content_negotiation
      end
      def self.load(path)
        @@langs = {}
        
        s = open(path) { |f| f.read }
        
        langs = nil
        system_default = nil
        
        [:languages, :system_default, :english_name, :native_name, :aliases].each { |optname|
          s.gsub!(/\{\{#{optname}\s*(.+?)\s*\}\}\s*\n+/i) {
            values = $1.split(/\s*,\s*/)
            case optname
              when :languages
                langs = values
                values.each { |lang|
                  @@langs[lang] = Translation.new(lang)
                  @@langs[lang].data = {}
                }
              when :system_default
                lang = values.shift
                @@langs[lang] = Translation.new(lang)
                @@langs[lang].data = nil
                system_default = lang
              when :aliases
                lang = values.shift
                @@langs[lang].send("#{optname}=", values)
              else
                lang = values.shift
                @@langs[lang].send("#{optname}=", values.first)
            end
            ''
          }
        }
        
        s.split(/###+\s*\n+/).each { |part|
          next if part =~ /\A\s*\Z/
          lines = part.split(/\n+/)
          key = lines.shift
          (type, path) = key.split(/\s+/,2)
          raise "Egalite::M17N::Translation.load: type should be 'html', 'msg' or 'img' but it was '#{type}'" unless %w[msg html img].include?(type)
          lines.each { |line|
            if type == 'img'
              langs.each { |lang|
                next unless @@langs[lang].data
                img = line.sub(/\.(jpg|jpeg|gif|png)/i,"_#{lang}.\\1")
                @@langs[lang].data[:img] ||= {}
                @@langs[lang].data[:img][path] ||= {}
                @@langs[lang].data[:img][path][line] = img
              }
            else
              a = line.split(/\s*\t+\s*/)
              k = nil
              a.each_with_index { |s,i|
                unless @@langs[langs[i]].data
                  k = s
                else
                  @@langs[langs[i]].data[type.to_sym] ||= {}
                  @@langs[langs[i]].data[type.to_sym][path] ||= {}
                  @@langs[langs[i]].data[type.to_sym][path][k] = s
                end
              }
            end
          }
        }
        @@langs
      end
      def self.lang(s)
        return nil unless s
        a =   @@langs.find { |k,v| v.fullmatch?(s) }
        a ||= @@langs.find { |k,v| v.partialmatch?(s) }
        a ? a.last : nil
      end
      private
      def method_path(c,a)
        c.class.name.to_s + '#' + a.to_s
      end
      def t_string(list, s)
        list[s] ? list[s] : s
      end
      def t_hash(list, h)
        if h.is_a?(EgaliteResponse)
          h.param = t_hash(list, h.param)
          return h
        end
        return h unless h.is_a?(Hash)
        h2 = {}
        h.each { |k,v|
          h2[k] = case v
            when String
              t_string(list,v)
            when Array
              v.map { |x| t_hash(list,x) }
            when Hash
              t_hash(list, v)
            else v
          end
        }
        h2
      end

    public

      attr_accessor :english_name, :native_name, :aliases, :data
      attr_reader :langcode
      
      def initialize(langcode)
        @langcode = langcode
        @aliases = []
      end
      def fullmatch?(lang)
        lang = lang.to_s.downcase
        @langcode == lang or @aliases.include?(lang)
      end
      def partialmatch?(lang)
        fullmatch?(lang.to_s.split(/(-|_)/).first)
      end
      def translate_html(path, html)
        return html unless @data
        list = @data[:html][path]
        return html unless list
        s = html.dup
        list.sort { |a,b| b[0].length <=> a[0].length }.each { |k,v| s.gsub!(k, v)}
        if @data[:img] and @data[:img][path]
          @data[:img][path].each { |k,v| s.gsub!(k, v) }
        end
        s
      end
      def translate_msg(controller, action, msg)
        return msg unless @data
        list = @data[:msg][method_path(controller,action)]
        return msg unless list
        t_hash(list, msg)
      end
      def translate_string(controller, action, string, placeholders = [])
        if @data
          list = @data[:msg][method_path(controller,action)]
          if list
            string = t_string(list, string)
          end
        end
        string = string.dup
        placeholders = placeholders.split(/\n/) unless placeholders.is_a?(Array)
        placeholders.each_with_index { |s2,i| string.gsub!(/\{#{i}\}/, s2) }
        string
      end
    end
  end
end
