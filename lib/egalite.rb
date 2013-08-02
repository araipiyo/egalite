$LOAD_PATH << File.dirname(__FILE__)

require "egalite/version"

require 'rack'
require 'egalite/blank'

require 'egalite/stringify_hash'

require 'egalite/template'
require 'egalite/route'
require 'egalite/session'
require 'egalite/helper'

require 'time'
require 'monitor'
require 'digest/md5'

module Rack
  module Utils
    def normalize_params(params,name,v)
      params[name] = v
    end
    module_function :normalize_params
  end
end

class CriticalError < RuntimeError
end

module Egalite

  module AccessLogger
   @@io = nil
   @@time = nil
   @@lock = Monitor.new
   class <<self
    def io=(io)
      @@io=io
    end
    def _open
      @@dir = dir
      @@time = Time.now
      fn = sprintf("egaliteaccess-%04d-%02d-%02d-p%d.log", @@time.year, @@time.month, @@time.mday, Process.pid)
      @@io = open(File.join(dir,fn), "a")
    end
    def open(dir)
      @@dir = dir
      yield
    ensure
      @@io.close if @@io
    end
    def write(line)
      return nil unless @@io
      
      @@lock.synchronize {
        if @@time and (@@time.mday != Time.now.mday)
          ## log rotation
          @@io.close
          _open
        end
        @@io.puts(line)
      }
    end
   end
  end
  
  class DebugLogger
    def initialize(path)
      @path = path
    end
    def puts(s)
      open(@path, "a") { |f|
        begin
          f.flock(File::LOCK_EX)
          f.puts s
          f.flush
        ensure
          f.flock(File::LOCK_UN)
        end
      }
    end
  end
  
  module ErrorLogger
   @@table = nil
   @@admin_emails = nil
   class <<self
    def table=(t)
      @@table=t
    end
    def admin_emails=(t)
      @@admin_emails=t
    end
    def write(hash)
      hash[:md5] = Digest::MD5.hexdigest(hash[:text]) unless hash[:md5]
      if hash[:severity] == 'critical' and @@admin_emails
        Sendmail.send(hash[:text],{
          :from => 'info@xcream.net',
          :to => @@admin_emails,
          :subject => 'Critical error at xcream.net'
        })
      end
      if @@table
        @@table.insert(hash) rescue nil
      end
    end
    def write_exception(e, hash)
      severity = 'exception'
      severity = 'security' if e.is_a?(SecurityError)
      severity = 'critical' if e.is_a?(CriticalError)
      
      text = "#{e.to_s}\n#{e.backtrace.join("\n")}"
      
      ErrorLogger.write({:severity => severity, :text => text}.merge(hash))
    end
   end
  end

class Controller
  attr_accessor :env, :req, :params, :template_file, :log_values
  undef id if defined? id

  # filters
  def before_filter
    true
  end
  def after_filter_return_value(response) # right after controller
    response
  end
  def after_filter_html(response) # html after template filter
    response
  end
  def after_filter(response) # after filter for final http output
    response
  end
  def filter_on_html_load(html, htmlfile)
    html
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
  
  def redirect_permanent(url)
    url = url_for(url) if url.is_a?(Hash)
    [301,{'Location' => url}, [url]]
  end
  
  def delegate(params)
    EgaliteResponse.new(:delegate, params)
  end
  def include(params)
    raw(req.handler.inner_dispatch(req, params)[2].to_s)
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
    @req.route.url_for(prms, req.host, req.port, req.scheme)
  end
  def link_to(title,prms)
    return tags.a(prms,title) if prms.is_a?(String)
    raw(@req.route.link_to(title,prms, req.host, req.port, req.scheme))
  end
  def raw(text)
    NonEscapeString.new(text)
  end
  def escape_html(s)
    tags.escape_html(s)
  end
  def tags
    HTMLTagBuilder
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
  def errorlog(severity, text)
    logid = Egalite::ErrorLogger.write(:severity => severity, :ipaddress => @req.ipaddr, :text => text, :url => @req.url)
    logid
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

module CSRFFilter
  def after_filter_return_value(response) # right after controller
    p "CSRFFilter"
    if session and session.sstr and response.is_a?(Hash)
      response.merge(:csrf => session.sstr)
    elsif session and session.sstr and response.is_a?(Sequel::Model)
      response[:csrf] = session.sstr
      response
    else
      response
    end
  end
end
class CSRFController < Controller
  def after_filter_return_value(response) # right after controller
    if session and session.sstr and response.is_a?(Hash)
      response.merge(:csrf => session.sstr)
    elsif session and session.sstr and response.is_a?(Sequel::Model)
      response[:csrf] = session.sstr
      response
    else
      response
    end
  end
end

class EgaliteError < RuntimeError
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
  attr_accessor :route, :controller, :action, :params, :path_info, :path_params
  attr_accessor :controller_class, :action_method, :inner_path
  attr_reader :rack_request, :time, :handler

  def initialize(values = {})
    @cookies = []
    @rack_request = values[:rack_request]
    @handler = values[:handler]
    @rack_env = values[:rack_env]
    @time = Time.now
  end
  def accept_language
    @rack_env['HTTP_ACCEPT_LANGUAGE']
  end
  def scheme
    @rack_request.scheme
  end
  def port
    @rack_request.port
  end
  def host
    @rack_request.host
  end
  def ipaddr
    @rack_request.ip
  end
  def path
    @rack_request.path
  end
  def url
    @rack_request.url
  end
  def referrer
    @rack_request.referrer
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

    @template_path = opts[:template_path] || 'pages/'
    @template_path << '/' if @template_path[-1..-1] != '/'
    @template_engine = opts[:template_engine] || HTMLTemplate
    
    @profile_logger = opts[:profile_logger]
    @notfound_template = opts[:notfound_template]
    @error_template = opts[:error_template]
    @admin_emails = opts[:admin_emails]
    @exception_log_table = opts[:exception_log_table]
    if @exception_log_table
      Egalite::ErrorLogger.table = db[@exception_log_table]
      Egalite::ErrorLogger.admin_emails = @admin_emails
    end
  end

 private
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
      [404, {"Content-Type" => "text/html"}, [load_template(@notfound_template)]]
    else
      [404, {"Content-Type" => "text/plain"}, ['404 not found']]
    end
  end
  def redirect(url)
    [302,{'Location' => url}, [url]]
  end
  def get_controller(controllername,action, method)
    action = method if action.blank?
    action.downcase!
    action.gsub!(/[^0-9a-z_]/,'')
    
    return nil if action == ""
    
    Controller.new.methods.each { |s| raise SecurityError if action == s }
    
    controllername ||= ''
    controllername = controllername.split('/').map { |c|
      c.downcase!
      c.gsub!(/[^0-9a-z]/,'')
      c.capitalize
    }.join
    controllername = 'Default' if controllername.blank?
    
    kontroller = Object.const_get(controllername+'Controller') rescue nil
    return nil unless kontroller
    
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
  
  def forbidden
    [403, {'Content-Type' => 'text/plain'}, ['Forbidden']]
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
    [500, {'Content-Type' => 'text/html'}, [html.join("\n")]]
  end
  
  def set_cookies_to_response(response,req)
    req.cookies.each { |k,v|
      cookie_opts = @opts[:cookie_opts] || {}
      unless v.is_a?(Hash)
        req.cookies[k] = {
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
    s = a.join("\n")
    response[1]['Set-Cookie'] = s
  end
  
 public
  def inner_dispatch(req, values)
    # recursive controller call to handle include tag or delegate.
    stringified = StringifyHash.create(values)
    (path, params) = req.route.get_path_and_params_from_params(stringified)
    newreq = req.clone
    newreq.params = params
    method = 'GET'
    method = values[:http_method] if values[:http_method]
    dispatch(path, params, method, newreq)
  end
  def run_controller(controller, action, req)
    # invoke controller
    controller.env = @env
    controller.req = req
    controller.params = req.params
    
    before_filter_result = controller.before_filter
    if before_filter_result != true
      return before_filter_result if before_filter_result.is_a?(Array)
      return forbidden unless before_filter_result.respond_to?(:command)
      response = case before_filter_result.command
       when :delegate
        inner_dispatch(req, before_filter_result.param)
       when :redirect
        redirect(before_filter_result.param)
       when :notfound
        display_notfound
       else
        forbidden
      end
      set_cookies_to_response(response,req)
      return response
    end
    
    nargs = controller.method(action).arity
    args = req.path_params[0,nargs.abs] || []
    if nargs > 0
      args.size.upto(nargs-1) { args << nil }
    end
    raise SecurityError unless controller.respond_to?(action, false)

    s = Time.now
    values = controller.send(action,*args)
    t = Time.now - s
    @profile_logger.puts "#{Time.now}: ctrl #{t}sec #{controller.class.name}.#{action} (#{req.path_info})" if @profile_logger
    
    values = controller.after_filter_return_value(values)
    
    # result handling
    result = if values.respond_to?(:command)
      case values.command
       when :delegate
        inner_dispatch(req, values.param)
       when :redirect
        redirect(values.param)
       when :notfound
        display_notfound
      end
    elsif values.is_a?(Array)
      values
    elsif values.is_a?(String)
      [200,{'Content-Type' => "text/html"},[values]]
    elsif values.is_a?(Rack::Response)
      values.to_a
    elsif values == nil
      raise "egalite error: controller returned nil as a response."
    else
      htmlfile = controller.template_file
      unless htmlfile
        htmlfile = [req.controller,req.action].compact.join('_')
        htmlfile = 'index' if htmlfile.blank?
        htmlfile += '.html'
      end
      html = load_template(@template_path + htmlfile)
      return [404, {"Content-Type" => "text/plain"}, ["Template not found: #{htmlfile}\n"]] unless html
      
      # apply on_html_load filter
      html = controller.filter_on_html_load(html, htmlfile)
      
      # apply html template
      template = @template_engine.new
      template.controller = controller

      s = Time.now
      template.handleTemplate(html,values) { |values|
        inner_dispatch(req,values)[2]
      }
      t = Time.now - s
      
      html = controller.after_filter_html(html)
      
      @profile_logger.puts "#{Time.now}: view #{t}sec #{controller.class.name}.#{action} (#{req.path_info})" if @profile_logger

      [200,{"Content-Type"=>"text/html"},[html]]
    end
    set_cookies_to_response(result,req)
    return result
  end
  
  def dispatch(path, params, method, req, first_call = false)
    # routing
    (controller_name, action_name, path_params, prmhash) = nil
    (controller, action) = nil
    
    route = @routes.find { |route|
      puts "Routing: matching: #{route.inspect}" if RouteDebug
      route_result = route.match(path)
      (controller_name, action_name, path_params, prmhash) = route_result
      next if route_result == nil
      puts "Routing: pre-matched: #{route_result.inspect}" if RouteDebug
      (controller, action) = get_controller(controller_name, action_name, method)
      true if controller
    }
    return display_notfound unless controller

    puts "Routing: matched: #{controller.class} #{action}" if RouteDebug
    params = prmhash.merge(params)
    
    req.route = route
    req.controller = controller_name
    req.controller_class = controller
    req.action = action_name
    req.action_method = action
    req.inner_path = path
    req.path_params = path_params
    req.path_info = path_params.join('/')

    # todo: language handling (by pathinfo?)
    # todo: session handling (by pathinfo?)
    
    res = run_controller(controller, action, req)
    
    if first_call
      controller.after_filter(res.to_a)
      
      # access log
      t = Time.now - req.time
      log = [req.time.iso8601, req.ipaddr, t, req.url, req.referrer]
      log += controller.log_values.to_a
      line = log.map {|s| s.to_s.gsub(/\t/,'')}.join("\t").gsub(/\n/,'')
      AccessLogger.write(line)
    end
    res
  end

  def call(rack_env)
    # set up logging
    
    res = nil

    req = Rack::Request.new(rack_env)
    
    begin
      ereq = Request.new(
        :rack_request => req,
        :rack_env => rack_env,
        :handler => self
      )

      # parameter handling
      params = StringifyHash.new
      req.params.each { |k,v|
#        raise 'egalite: no multiple query parameter allowed in same keyword.' if v.is_a?(Array)
         next unless k
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
      
      ereq.params = params
      ereq.cookies = req.cookies

      authorization_keys = ['HTTP_AUTHORIZATION', 'X-HTTP_AUTHORIZATION', 'X_HTTP_AUTHORIZATION']
      key = authorization_keys.detect { |key| rack_env.has_key?(key) }
      ereq.authorization = rack_env[key] if key
      
      if @opts[:session_handler]
        ereq.session = @opts[:session_handler].new(@env,ereq.cookies, @opts[:session_opts] || {})
        ereq.session.load
      end
      
      res = dispatch(req.path_info, params, req.request_method, ereq, true)
      res = res.to_a

      puts "after-cookie: #{res[1]['Set-Cookie'].inspect}" if @opts[:cookie_debug]
      
      if res[0] == 200
        if res[1]['Content-Type'] !~ /charset/i and res[1]['Content-Type'] =~ /text\/html/i
          res[1]["Content-Type"] = @opts[:charset] || 'text/html; charset=utf-8'
        end
      end
      
     rescue Exception => e
      raise e if $raise_exception
      
      begin
        # write error log
        logid = nil
        if @exception_log_table
          logid = ErrorLogger.write_exception(e,{:ipaddress => req.ip, :url => req.url})
        end
        
        # show exception
        
        if @error_template
          values = {}
          values[:logid] = logid if logid
          values[:exception] = e.to_s
          values[:backtrace] = e.backtrace
          html = @template_engine.new.handleTemplate(@error_template.dup,values)
          res = [500, {"Content-type"=>"text/html; charset=utf-8"}, [html]]
        else
          res = display_internal_server_error(e)
        end
      rescue Exception => e2
        res = display_internal_server_error(e2)
      end
    end
    
    res = res.to_a
    p res if @opts[:response_debug]
    res
  end
end

end # module end

class StaticController < Egalite::Controller
  def get
    raise SecurityError unless env.opts[:static_root]
    
    path = req.path_info
    path.gsub!(/[^0-9a-zA-Z\(\)\. \/_\-]/,'')
    if path.include?("..") or path =~ /^\//
      return [403, {"Content-Type" => "text/plain"}, ["Forbidden\n"]]
    end
    path = File.join(env.opts[:static_root], path)
    send_file(path)
  end
end
