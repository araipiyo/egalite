$LOAD_PATH << File.dirname(__FILE__)

require 'rack'
require 'blank'

require 'stringify_hash'

require 'template'
require 'route'
require 'session'
require 'helper'

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
  attr_accessor :env, :params, :template_file
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
    @env.cookies
  end
  def session
    @env.session
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
  
  def delegate(url)
    url = url_for(url) if url.is_a?(Hash)
    EgaliteResponse.new(:delegate, url)
  end
  def send_data(data, content_type)
    Rack::Response.new(data,200,{"Content-Type" => content_type})
  end
  
  # helpers
  def url_for(prms)
    @env.route.url_for(prms)
  end
  def link_to(title,prms)
    raw(@env.route.link_to(title,prms))
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
end

class EgaliteError < RuntimeError
end
class CrackAttempt < EgaliteError
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
  attr_accessor :session, :language, :cookies
  attr_accessor :route, :controller, :action, :params
  attr_reader :db, :method

  def initialize(db,method)
    @session = nil
    @language = nil
    @db = db
    @cookies = []
    @method = method
  end
end

class Handler
  attr_accessor :routes
  
  def initialize(opts = {})
    @routes = opts[:routes] || Route.default_routes
    
    @env = nil

    @db = opts[:db]
    @opts = opts

    @logger = Logger.new
    
    @template_path = 'pages/'
    @template_engine = HTMLTemplate
    
    @notfound_template = nil
    @error_template = nil
  end

 private
  def load_template(tmpl)
    # to expand: template caching
    open(tmpl) { |f| f.read }
  end

  def escape_html(s)
    Rack::Utils.escape_html(s)
  end
  
  def display_notfound
    if @notfound_template
      Rack::Response.new(load_template(@notfound_template),404)
    else
      Rack::Response.new('404 not found',404)
    end
  end
  def redirect(url)
    Rack::Response.new(url,302,{'Location' => url})
  end
  def get_controller(controllername,action, method)
    action = method if action.blank?
    action.downcase!
    action.gsub!(/[^0-9a-z_]/,'')
    Controller.new.methods.each { |s| raise CrackAttempt if action == s }
    
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
    Rack::Response.new(html.join("\n"),500)
  end
  
  def handle_egalite_response(values)
    case values.command
      when :delegate
        dispatch(values.param,values) # todo: ‚Ü‚¾‚Å‚«‚Ä‚È‚¢
      when :redirect
        redirect(values.param)
      when :template
        # todo
      when :notfound
        display_notfound
      when :csv
        # todo
    end
  end
  def set_cookies_to_response(response)
    @env.cookies.each { |k,v|
      cookie_opts = @opts[:cookie_opts] || {}
      unless v.is_a?(Hash)
        v = {
          :value => v.to_s,
          :expires => Time.now + (cookie_opts[:expire_after] || 3600),
          :path => cookie_opts[:path] || '/',
          :secure => cookie_opts[:secure] || false
        }
      end
      response.set_cookie(k,v)
    }
  end

 public
  def dispatch(path, params, method)
    # routing
    (controller_name, action_name, path_params, prmhash) = nil
    (controller, action) = nil
    route = @routes.find { |route|
      @logger.puts "Routing: matching: #{route.inspect}" if RouteDebug
      route_result = route.match(path)
      (controller_name, action_name, path_params, prmhash) = route_result
      next if route_result == nil
      @logger.puts "Routing: pre-matched: #{route_result.inspect}" if RouteDebug
      (controller, action) = get_controller(controller_name, action_name, method)
      true if controller
    }
    return display_notfound unless controller

    @logger.puts "Routing: matched: #{controller.class} #{action}" if RouteDebug
    params.merge!(prmhash)
    
    @env.route = route
    @env.controller = controller_name
    @env.action = action_name

    # todo: language handling (by pathinfo?)
      
    # todo: session handling (by pathinfo?)
      
      
    # controller
    controller.env = @env
    controller.params = params
    
    before_filter_result = controller.before_filter
    if before_filter_result != true
      response = handle_egalite_response(before_filter_result)
      set_cookies_to_response(response)
      return response
    end
    
    nargs = controller.method(action).arity
    args = []
    args = path_params[0,nargs.abs] || []
    if nargs > 0
      args.size.upto(nargs-1) { args << nil }
    end
    values = controller.send(action,*args)
    
    # result handling
    result = if values.respond_to?(:command)
      handle_egalite_response(values)
    elsif values.is_a?(String)
      Rack::Response.new(values,200)
    elsif values.is_a?(Rack::Response)
      values
    else
      htmlfile = if controller.template_file
        controller.template_file
      else
        ([@env.controller,@env.action].compact.join('_') || 'index')+'.html'
      end
      html = load_template(@template_path + htmlfile)
      # apply html template
      template = HTMLTemplate.new
      template.controller = controller
      template.handleTemplate(html,values) { |path,values|
        dispatch(path,values) # recursive call to handle 'include' tag.
      }
      Rack::Response.new(html,200)
    end
    set_cookies_to_response(result)
    return result
  end

  def call(rack_env)
    # set up logging
    
    start_time = Time.now
    res = nil
    
    begin
      req = Rack::Request.new(rack_env)
      @env = Environment.new(@db, req.request_method)
      
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
      
      @env.params = params
      @env.cookies = req.cookies
      
      if @opts[:session_handler]
        @env.session=@opts[:session_handler].new(@env,@opts[:session_opts] || {})
        @env.session.load
      end
      
      # todo: language handling (by cookie/header)
      
      
      res = dispatch(req.path_info, params, req.request_method)
      
      if res.status == 200
        if res['Content-Type'] !~ /charset/i and res['Content-Type'] =~ /text\/html/i
          res["Content-Type"] = @opts[:charset] || 'text/html; charset=utf-8'
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
    
    finish_time = Time.now
    
    # write log
    
    res = res.to_a
    p res if @opts[:response_debug]
    res
  end
end

end # module end
