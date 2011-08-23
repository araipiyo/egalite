
module Egalite
  module M17N
    
    
    module Filters
      def before_filter
        # check hostname first to determine which language to serve.
        first = req.host.split(/\./).first
        @lang = Translation.lang(first)
        if not @lang and req.accept_language
          # fallback to Accept-Language HTTP header for language to serve.
          langs = req.accept_language.split(/,/)
          @lang = langs.map { |s| Translation.lang(s.split(/;/).first) }.compact.first
        end
        @lang ||= Translation.lang(Translation.user_default_lang)
        @lang ||= Translation.lang('ja')
        
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
    end
    class Controller < Egalite::Controller
      include Filters
    end
    
    
    class Translation
      class <<self
        attr_accessor :langs, :user_default_lang
      end
      def self.load(dir)
          # translation files should be named as "en.txt", "en-us.txt"
          
          @@langs = {}
          Dir.entries(dir).each { |fn|
            next unless fn =~ /\A([a-z-]+)\.txt\Z/
            lang = $1.downcase
            s = open(File.join(dir,fn)) { |f| f.read }
            
            opts = {}
            [:english_name, :native_name, :aliases].each { |optname|
              s.sub!(/\{\{#{optname}\s*(.+?)\s*\}\}\s*\n+/i) {
                opts[optname] = $1
                ''
              }
            }
            if s =~ /\{\{system_default\}\}/
              @@langs[lang] = self.new(lang, nil, opts)
              next
            end
            
            data = {}
            s.split(/###+\s*\n+/).each { |part|
              next if part =~ /\A\s*\Z/
              lines = part.split(/\n+/)
              key = lines.shift
              (type, path) = key.split(/\s+/,2)
              raise "Egalite::M17N::Translation.load: type should be 'html', 'msg' or 'img' but it was '#{type}'" unless %w[msg html img].include?(type)
              hash = {}
              lines.each { |line|
                if type == 'img'
                  hash[line] = line.sub(/\.(jpg|jpeg|gif|png)/i,"_#{lang}.\\1")
                else
                  (k,v) = line.split(/\s*\t+\s*/,2)
                  hash[k] = v
                end
              }
              data[type.to_sym] ||= {}
              data[type.to_sym][path] = hash
            }
            @@langs[lang] = self.new(lang, data, opts)
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
            when String: t_string(list,v)
            when Array: v.map { |x| t_hash(list,x) }
            when Hash: t_hash(list, v)
            else v
          end
        }
        h2
      end
      public
      def initialize(langcode, data, opt)
        @langcode = langcode
        @data = data
        @english_name = opt[:english_name]
        @native_name = opt[:native_name]
        @aliases = opt[:aliases].to_s.split(/\s*,\s*/).map(&:downcase)
      end
      def fullmatch?(lang)
        lang = lang.to_s.downcase
        @langcode == lang or @aliases.include?(lang)
      end
      def partialmatch?(lang)
        fullmatch?(lang.to_s.split(/-/).first)
      end
      def translate_html(path, html)
        return html unless @data
        list = @data[:html][path]
        return html unless list
        s = html.dup
        list.each { |k,v| s.gsub!(k, v) }
        list_img = @data[:img][path]
        if list_img
          list_img.each { |k,v| s.gsub!(k, v) }
        end
        s
      end
      def translate_msg(controller, action, msg)
        return msg unless @data
        list = @data[:msg][method_path(controller,action)]
        return msg unless list
        t_hash(list, msg)
      end
    end
  end
end
