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
    path.sub!(/^\/+/,'')
    pathary = path.split('/')
    controller = nil
    action = nil
    path_params = []
    params = {}
    prefix = []
    @route.each { |fragment|
      command = fragment[0]
      
      case command
        when :controller
          return nil if pathary.empty?
          controller += '/' if controller
          controller ||= ''
          controller += pathary.shift
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
  def url_for(params)
    route = @route || []
    pathary = []
    controller_exist = false
    action_exist = false
    contfrags = (@controller || "").split('/')
    # todo: protocol and domain.
    route.each { |fragment|
      command = fragment[0]
      
      case command
        when :controller
          next if controller_exist
          if params[:controller] == nil
            pathary += contfrags
          elsif params[:controller] =~ /^\//
            pathary += params[:controller].split('/')
          else
            pathary += contfrags[0..-2]
            pathary += params[:controller].split('/')
          end
          controller_exist = pathary.size
          params.delete(:controller)
        when :action
          pathary << params[:action] || @action
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
          ary = params[:params] || []
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
      pathary.unshift(params[:controller].split('/'))
      params.delete(:controller)
    end
    pathary = pathary.compact.map { |frag| escape(frag) }
    path = "/" + pathary.join('/').sub(/\/+$/,'').sub(/^\//,'')
    if params and params.size > 0
      q = []
      params.each { |k,v|
        q << "#{escape(k)}=#{escape(v)}"
      }
      path += "?" + q.join('&')
    end
    path
  end
  def link_to(title, params)
    "<a href='#{url_for(params)}'>#{title}</a>"
  end
  def url_pcap(prefix, controller, action, params)
  end
  def url_cap(controller, action, params)
  end
  def url_ap(action, params)
  end
  def url_p(params)
  end
end
end
