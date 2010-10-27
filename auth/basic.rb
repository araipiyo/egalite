
module Egalite
  module Auth
    class Basic
      def self.authorize(req,realm)
        auth = req.authorization
        return unauthorized(realm) if auth.blank?
        (method,credentials) = auth.split(' ', 2)
        return bad_request if method.downcase != "basic"
        (username,password) = credentials.unpack("m*").first.split(/:/,2)
        return unauthorized(realm) unless yield(username,password)
        true
      end
      def self.unauthorized(realm)
        return [ 401,
          { 'Content-Type' => 'text/plain',
            'Content-Length' => '0',
            'WWW-Authenticate' => 'Basic realm="%s"' % realm },
          []
        ]
      end
      def self.bad_request
        return [ 400,
          { 'Content-Type' => 'text/plain',
            'Content-Length' => '0' },
          []
        ]
      end
    end
  end
end

