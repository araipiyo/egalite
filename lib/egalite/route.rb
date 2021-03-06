module Egalite
class Route
  def initialize(route_def)
    @route = route_def
    @controller = nil
    @prefix = nil
    @action = nil
  end
  def self.default_routes
    routes = []
    routes << Route.new([
      [:controller],
      [:controller],
      [:action],
      [:param_arg, :id],
      [:params]
    ])
    routes << Route.new([
      [:controller],
      [:controller],
      [:param_arg, :id],
      [:params]
    ])
    routes << Route.new([
      [:controller],
      [:action],
      [:param_arg, :id],
      [:params]
    ])
    routes << Route.new([
      [:controller],
      [:param_arg, :id],
      [:params]
    ])
    routes << Route.new([
      [:action],
      [:param_arg, :id],
      [:params]
    ])
    routes << Route.new([
      [:param_arg, :id],
      [:params]
    ])
    routes
  end


  def match(path)
    path = path.sub(/^\/+/,'')
    pathary = path.to_s.split('/')
    controller = nil
    action = nil
    path_params = []
    params = {}
    prefix = []
    @route.each { |fragment|
      command = fragment[0]
      
      case command
        when :controller
          if pathary.empty? and controller
            controller += '/index'
          elsif pathary.empty?
            return nil
          else
            controller += '/' if controller
            controller ||= ''
            controller += pathary.shift
          end
        when :action
          return nil if pathary.empty?
          action = pathary.shift
        when :param
          next if pathary.empty?
          val = pathary.shift
          params[fragment[1]] = val
          prefix << val unless controller
        when :param_arg
          next if pathary.empty?
          val = pathary.shift
          params[fragment[1]] = val if fragment[1]
          path_params << val
          prefix << val unless controller
        when :param_fix
          return nil if pathary[0] != fragment[2]
          params[fragment[1]] = pathary.shift
          prefix << val unless controller
        when :controller_fix
          return nil if pathary[0] != fragment[1]
          controller += '/' if controller
          controller ||= ''
          controller += pathary.shift
        when :params
          path_params += pathary
          pathary = []
      end
    }
    return nil if pathary.size > 0
    @controller = controller
    @action = action
    @path_params = path_params
    @params = params
    @prefix = prefix.join('/')
    [controller, action, path_params, params]
  end

  def escape(s)
    Rack::Utils.escape(s)
  end

  def get_path_and_params_from_params(params, current_host = nil, current_port = nil, current_scheme = nil)
    route = @route || []
    pathary = []
    controller_exist = false
    action_exist = false
    contfrags = (@controller || "").to_s.split('/')
    
    scheme = nil
    host = nil
    port = nil
    if params[:scheme]
      scheme = params[:scheme].to_s
      params.delete(:scheme)
    end
    if params[:host]
      host = params[:host]
      params.delete(:host)
    end
    if params[:port]
      port = params[:port].to_i
      params.delete(:port)
    end
    if (scheme or port or host)
      raise "get_path_and_params_from_params: current_host is not supplied." unless host or current_host
      scheme = scheme || current_scheme || 'http'
      prefix = "#{scheme}://#{host || current_host}"
      unless (current_scheme == 'http' and current_port == 80) or (current_scheme == 'https' and current_port == 443)
        port ||= current_port
      end
      if port
        unless (scheme == 'http' and port == 80) or (scheme == 'https' and port == 443)
          prefix << ":#{port}"
        end
      end
    end
    
    route.each { |fragment|
      command = fragment[0]
      
      case command
        when :controller
          next if controller_exist
          if params[:controller] == nil
            pathary += contfrags
          elsif params[:controller] =~ /^\//
            pathary += params[:controller].to_s.split('/')
          else
            pathary += contfrags[0..-2]
            pathary += params[:controller].to_s.split('/')
          end
          controller_exist = pathary.size
          params.delete(:controller)
        when :action
          pathary << (params[:action] || (controller_exist ? nil : @action))
          action_exist = true
          params.delete(:action)
        when :param
          pathary << params[fragment[1]]
          params.delete(fragment[1])
        when :param_arg
          pathary << params[fragment[1]]
          params.delete(fragment[1])
        when :param_fix
          value = params[fragment[1]]
          value = fragment[2] unless value
          pathary << params[fragment[1]]
          params.delete(fragment[1])
        when :controller_fix
          next
        when :params
          ary = (params[:params] || [])
          if ary.respond_to?(:map)
            pathary += ary.map { |s| s.to_s }
          else
            pathary += [ary.to_s]
          end
          params.delete(:params)
      end
    }
    if not action_exist and params[:action]
      if controller_exist
        pathary.insert(controller_exist,params[:action])
      else
        pathary.unshift(params[:action])
      end
      params.delete(:action)
    end
    if not controller_exist and params[:controller]
      pathary.unshift(params[:controller].to_s.split('/')).flatten!
      params.delete(:controller)
    end
    pathary = pathary.compact.map { |frag| escape(frag) }
    path = "/" + pathary.join('/').sub(/\/+$/,'').sub(/^\//,'')
    
    [path, params, pathary, prefix]
  end

  def url_for(params, host = nil, port = nil, scheme = nil)
    (path, params, z, prefix) = get_path_and_params_from_params(params, host, port, scheme)
    if params and params.size > 0
      q = []
      params.each { |k,v|
        if v.is_a?(Hash)
          v.each { |k2,v2|
            next if v2 == nil
            q << "#{escape(k)}[#{escape(k2)}]=#{escape(v2)}"
          }
        else
          q << "#{escape(k)}=#{escape(v)}" if v
        end
      }
      path += "?" + q.join('&') unless q.empty?
    end
    "#{prefix}#{path}"
  end

  def link_to(title, params, host = nil, port = nil, scheme = nil)
    "<a href='#{url_for(params, host, port, scheme)}'>#{title}</a>"
  end
end
end
