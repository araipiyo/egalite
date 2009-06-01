$LOAD_PATH << File.dirname(__FILE__)

require 'rack'
require 'blank'

require 'stringify_hash'

require 'template'
require 'route'
require 'session'
require 'helper'

module Rack
  module Utils
    def normalize_params(params,name,v)
      params[name] = v
    end
    module_function :normalize_params
  end
end

module Egalite

class Logger
  def puts(s)
    Kernel.puts s
  end
  def p(s)
    Kernel.p s
  end
end

class Controller
  attr_accessor :env, :req, :params, :template_file
  undef id

  # filters
  def before_filter
    true
  end
  def after_filter
    true
  end
  
  # accessors
  def db
    @env.db
  end
  def cookies
    @req.cookies
  end
  def session
    @req.session
  end
  def id
    @params[:id]
  end
  
  # results
  def notfound
    EgaliteResponse.new(:notfound)
  end
  def redirect(url)
    url = url_for(url) if url.is_a?(Hash)
    EgaliteResponse.new(:redirect, url)
  end
  alias :redirect_to :redirect
  
  def delegate(params)
    EgaliteResponse.new(:delegate, params)
  end
  def send_file(path, content_type = nil)
    ext = File.extname(path)[1..-1]

    if File.file?(path) && File.readable?(path)
      s = nil
      open(path, "rb") { |file|
        s = file.read
      }
      return [200, {
         "Last-Modified"  => File.mtime(path).rfc822,
         "Content-Type"   => content_type || MIME_TYPES[ext] || "text/plain",
         "Content-Length" => File.size(path).to_s
       }, s]
    else
      return [404, {"Content-Type" => "text/plain"}, ["File not found\n"]]
    end
  end
  def send_data(data, content_type)
    [200,{"Content-Type" => content_type},[data]]
  end
  
  # helpers
  def url_for(prms)
    @req.route.url_for(prms)
  end
  def link_to(title,prms)
    raw(@req.route.link_to(title,prms))
  end
  def raw(text)
    NonEscapeString.new(text)
  end
  def table_by_array(header,content,opts={})
    TableHelper.table_by_array(header,content,opts)
  end
  def form(data={},param_name = nil, opts = {})
    FormHelper.new(data,param_name,opts)
  end
  def file_form(data={},param_name = nil, opts = {})
    FormHelper.new(data,param_name,opts.merge(:enctype => 'multipart/form-data'))
  end

  # From WEBrick.
  MIME_TYPES = {
    "ai"    => "application/postscript",
    "asc"   => "text/plain",
    "avi"   => "video/x-msvideo",
    "bin"   => "application/octet-stream",
    "bmp"   => "image/bmp",
    "class" => "application/octet-stream",
    "cer"   => "application/pkix-cert",
    "crl"   => "application/pkix-crl",
    "crt"   => "application/x-x509-ca-cert",
   #"crl"   => "application/x-pkcs7-crl",
    "css"   => "text/css",
    "dms"   => "application/octet-stream",
    "doc"   => "application/msword",
    "dvi"   => "application/x-dvi",
    "eps"   => "application/postscript",
    "etx"   => "text/x-setext",
    "exe"   => "application/octet-stream",
    "gif"   => "image/gif",
    "htm"   => "text/html",
    "html"  => "text/html",
    "jpe"   => "image/jpeg",
    "jpeg"  => "image/jpeg",
    "jpg"   => "image/jpeg",
    "js"    => "text/javascript",
    "lha"   => "application/octet-stream",
    "lzh"   => "application/octet-stream",
    "mov"   => "video/quicktime",
    "mpe"   => "video/mpeg",
    "mpeg"  => "video/mpeg",
    "mpg"   => "video/mpeg",
    "pbm"   => "image/x-portable-bitmap",
    "pdf"   => "application/pdf",
    "pgm"   => "image/x-portable-graymap",
    "png"   => "image/png",
    "pnm"   => "image/x-portable-anymap",
    "ppm"   => "image/x-portable-pixmap",
    "ppt"   => "application/vnd.ms-powerpoint",
    "ps"    => "application/postscript",
    "qt"    => "video/quicktime",
    "ras"   => "image/x-cmu-raster",
    "rb"    => "text/plain",
    "rd"    => "text/plain",
    "rtf"   => "application/rtf",
    "sgm"   => "text/sgml",
    "sgml"  => "text/sgml",
    "tif"   => "image/tiff",
    "tiff"  => "image/tiff",
    "txt"   => "text/plain",
    "xbm"   => "image/x-xbitmap",
    "xls"   => "application/vnd.ms-excel",
    "xml"   => "text/xml",
    "xpm"   => "image/x-xpixmap",
    "xwd"   => "image/x-xwindowdump",
    "zip"   => "application/zip",
  }
end

class EgaliteError < RuntimeError
end
class SecurityError < EgaliteError
end
class EgaliteResponse
  attr_accessor :command
  attr_accessor :param
  
  def initialize(com, param = nil)
    @command = com
    @param = param
  end
end

class Environment
  attr_reader :db, :opts

  def initialize(db,opts)
    @db = db
    @opts = opts
  end
end

class Request
  attr_accessor :session, :cookies, :authorization
  attr_accessor :language, :method
  attr_accessor :route, :controller, :action, :params, :path, :path_params

  def initialize
    @cookies = []
  end
end

class Handler
  attr_accessor :routes
  
  def initialize(opts = {})
    @routes = opts[:routes] || Route.default_routes
    
    db = opts[:db]
    @db = db
    @opts = opts
    @env = Environment.new(db, opts)
    opts[:static_root] ||= "static/"

    @logger = Logger.new
    
    @template_path = 'pages/'
    @template_engine = HTMLTemplate
    
    @notfound_template = nil
    @error_template = nil
    
    @profile = {}
  end

 private
  def profile(key)
    st = Time.now
    r = yield
    fn = Time.now
    @profile[key] = (@profile[key] || 0.0) + (fn - st)
    r
  end
 
  def load_template(tmpl)
    # to expand: template caching
    if File.file?(tmpl) && File.readable?(tmpl)
      open(tmpl) { |f| f.read }
    else
      nil
    end
  end

  def escape_html(s)
    Rack::Utils.escape_html(s)
  end
  
  def display_notfound
    if @notfound_template
      [404, {}, [load_template(@notfound_template)]]
    else
      [404, {}, ['404 not found']]
    end
  end
  def redirect(url)
    [302,{'Location' => url}, [url]]
  end
  def get_controller(controllername,action, method)
    action = method if action.blank?
    action.downcase!
    action.gsub!(/[^0-9a-z_]/,'')
    Controller.new.methods.each { |s| raise SecurityError if action == s }
    
    controllername ||= ''
    controllername = controllername.split('/').map { |c|
      c.downcase!
      c.gsub!(/[^0-9a-z]/,'')
      c.capitalize!
    }.join
    controllername = 'Default' if controllername.blank?
    
    kontroller = nil
    begin
      kontroller = Object.const_get(controllername+'Controller')
    rescue Exception => e
      return nil
    end
    
    controller = kontroller.new
    method = method.downcase
    
    unless controller.respond_to?(action)
      if controller.respond_to?("#{action}_#{method}")
        action = "#{action}_#{method}"
      else
        return nil
      end
    end
    [controller, action]
  end
  
  def display_internal_server_error(e)
    html = [
    "<html><body>",
    "<h1>Internal server error.</h1>"
    ]
    if ShowException
      html += [
        "<p>Exception: #{escape_html(e.to_s)}</p>",
        "<h2>Back trace</h2>",
        "<p>#{e.backtrace.map{|s|escape_html(s)}.join("<br/>\n")}</p>"
      ]
    end
    html << "</body></html>"
    [500, {}, [html.join("\n")]]
  end
  
  def set_cookies_to_response(response,req)
    req.cookies.each { |k,v|
      cookie_opts = @opts[:cookie_opts] || {}
      unless v.is_a?(Hash)
        v = {
          :value => v.to_s,
          :expires => Time.now + (cookie_opts[:expire_after] || 3600),
          :path => cookie_opts[:path] || '/',
          :secure => cookie_opts[:secure] || false
        }
      end
    }
    a = req.cookies.map { |k,v|
      s = "#{Rack::Utils.escape(k)}=#{Rack::Utils.escape(v[:value])}"
      s += "; domain=#{v[:domain]}" if v[:domain]
      s += "; path=#{v[:path]}" if v[:path]
      s += "; expires=#{v[:expires].clone.gmtime.strftime("%a, %d-%b-%Y %H:%M:%S GMT")}" if v[:expires]
      s += "; secure" if v[:secure]
      s
    }
    s = a.join(',')
    response[1]['Set-Cookie'] = s
  end
  
  def inner_dispatch(req, values)
    # recursive call to handle include tag or delegate.
    newreq = req.clone
    values = StringifyHash.create(values)
    if values[:controller]
      if values[:controller] =~ /^\//
        newreq.controller = values[:controller]
      else
        cont_path = (req.controller.split('/'))[0..-2]
        cont_path << values[:controller]
        newreq.controller = cont_path.join('/')
      end
    else
      newreq.controller = req.controller
    end
    path_params = []
    action = values[:action].to_s
    if action.split('/').size > 1
      a = action.split('/')
      action = a[0]
      path_params += a[1..-1]
    end
    path_params += values[:path_params] || []
    newreq.action = action
    newreq.params = req.params.merge(values)
    newreq.path_params = path_params.flatten
    newreq.path = path_params.join('/')
    (cont, act) = get_controller(newreq.controller, newreq.action, 'GET')
    raise "Egalite::Handler#inner_dispatch: controller or HTML not found: #{newreq.controller} #{newreq.action}" unless cont
    run_controller(cont, act, newreq)
  end

 public
  def run_controller(controller, action, req)
    # invoke controller
    controller.env = @env
    controller.req = req
    controller.params = req.params
    
    before_filter_result = controller.before_filter
    if before_filter_result != true
      return before_filter_result if before_filter_result.is_a?(Array)
      response = case before_filter_result.command
       when :delegate
        inner_dispatch(req, before_filter_result.param)
       when :redirect
        redirect(before_filter_result.param)
       when :template
        # todo
       when :notfound
        display_notfound
       when :csv
        # todo
      end
      set_cookies_to_response(response,req)
      return response
    end
    
    nargs = controller.method(action).arity
    args = req.path_params[0,nargs.abs] || []
    if nargs > 0
      args.size.upto(nargs-1) { args << nil }
    end
    values = profile(:controller) { controller.send(action,*args) }
    
    # result handling
    result = if values.respond_to?(:command)
      case values.command
       when :delegate
        inner_dispatch(req, values.param)
       when :redirect
        redirect(values.param)
       when :template
        # todo
       when :notfound
        display_notfound
       when :csv
        # todo
      end
    elsif values.is_a?(Array)
      values
    elsif values.is_a?(String)
      [200,{'Content-Type' => "text/html"},[values]]
    elsif values.is_a?(Rack::Response)
      values.to_a
    else
      htmlfile = controller.template_file
      unless htmlfile
        htmlfile = [req.controller,req.action].compact.join('_')
        htmlfile = 'index' if htmlfile.blank?
        htmlfile += '.html'
      end
      html = load_template(@template_path + htmlfile)
      return [404, {"Content-Type" => "text/plain"}, ["Template not found: #{htmlfile}\n"]] unless html
      # apply html template
      template = HTMLTemplate.new
      template.controller = controller
      template.handleTemplate(html,values) { |values|
        inner_dispatch(req,values)[2]
      }
      [200,{"Content-Type"=>"text/html"},[html]]
    end
    set_cookies_to_response(result,req)
    return result
  end
  
  def dispatch(path, params, method, req)
    # routing
    (controller_name, action_name, path_params, prmhash) = nil
    (controller, action) = nil
    
    route = profile(:routing) { 
     @routes.find { |route|
      @logger.puts "Routing: matching: #{route.inspect}" if RouteDebug
      route_result = route.match(path)
      (controller_name, action_name, path_params, prmhash) = route_result
      next if route_result == nil
      @logger.puts "Routing: pre-matched: #{route_result.inspect}" if RouteDebug
      (controller, action) = get_controller(controller_name, action_name, method)
      true if controller
     }
    }
    return display_notfound unless controller

    @logger.puts "Routing: matched: #{controller.class} #{action}" if RouteDebug
    params.merge!(prmhash)
    
    req.route = route
    req.controller = controller_name
    req.action = action_name
    req.path_params = path_params
    req.path = path_params.join('/')

    # todo: language handling (by pathinfo?)
    # todo: session handling (by pathinfo?)
    
    run_controller(controller, action, req)
  end

  def call(rack_env)
    # set up logging
    
    res = nil
    @profile = {}
    
    profile(:total) {
     begin
      req = Rack::Request.new(rack_env)
      
      # parameter handling
      params = StringifyHash.new
      req.params.each { |k,v|
#        raise 'egalite: no multiple query parameter allowed in same keyword.' if v.is_a?(Array)
         frags = k.split(/[\]\[]{1,2}/)
         last = frags.pop
         list = params
         frags.each { |frag|
           list[frag] ||= StringifyHash.new
           list = list[frag]
         }
         list[last] = v
      }

      puts "before-cookie: #{req.cookies.inspect}" if @opts[:cookie_debug]
      
      ereq = Request.new
      ereq.params = params
      ereq.cookies = req.cookies

      authorization_keys = ['HTTP_AUTHORIZATION', 'X-HTTP_AUTHORIZATION', 'X_HTTP_AUTHORIZATION']
      key = authorization_keys.detect { |key| rack_env.has_key?(key) }
      ereq.authorization = rack_env[key] if key
      
      if @opts[:session_handler]
        ereq.session = @opts[:session_handler].new(@env,ereq.cookies, @opts[:session_opts] || {})
        ereq.session.load
      end
      
      # todo: language handling (by cookie/header)
      
      res = dispatch(req.path_info, params, req.request_method, ereq)
      res = res.to_a

      puts "after-cookie: #{res[1]['Set-Cookie'].inspect}" if @opts[:cookie_debug]
      
      if res[0] == 200
        if res[1]['Content-Type'] !~ /charset/i and res[1]['Content-Type'] =~ /text\/html/i
          res[1]["Content-Type"] = @opts[:charset] || 'text/html; charset=utf-8'
        end
      end
      
     rescue Exception => e
      begin
        # error handling here
        
        # write error log
        
        # show exception
        
        if @error_template
        else
          res = display_internal_server_error(e)
        end
      rescue Exception => e2
        res = display_internal_server_error(e2)
      end
     end
    }
    
    # write log
    
    p @profile if @opts[:log_execution_time]
    
    res = res.to_a
    p res if @opts[:response_debug]
    res
  end
end

end # module end

class StaticController < Egalite::Controller
  def get
    path = req.path
    if path.include?("..") or path =~ /^\//
      return [403, {"Content-Type" => "text/plain"}, ["Forbidden\n"]]
    end
    path = File.join(env.opts[:static_root], path)
    send_file(path)
  end
end
