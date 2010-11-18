
require 'openssl'

module Egalite
class Session
  attr_accessor :expire_after, :hash, :cookie_name

  def initialize(env, cookies, opts = {})
    @env = env
    @cookies = cookies
    @cookie_name = opts[:cookie_name] || 'egalite_session'
    @expire_after = opts[:expire_after] || (86400 * 30)
    @secure = opts[:secure] || false
    @path = opts[:path] || '/'
    @hash = {}
    @loaded = false
  end
  def create
    raise NotImplementedError
  end
  def load
    raise NotImplementedError
  end
  def save
    raise NotImplementedError
  end
  def delete
    raise NotImplementedError
  end
  def [](k)
    @hash[k]
  end
  def []=(k,v)
    @hash[k] = v
  end
end
class SessionSequel < Session
  def self.create_table(db, opts = {})
    table = opts[:table_name] || :sessions
    
    db.create_table(table) {
      primary_key :id, :integer, :auto_increment => true
      column :mac, :varchar
      column :updated_at, :timestamp
    }
  end

  def initialize(env, cookies, opts = {}) 
    @db = env.db
    @table = opts[:tablename] || :sessions
    
    super(env, cookies, opts)
  end
  def cookie
    {
      :value => @sstr,
      :expires => Time.now + @expire_after,
      :path => @path,
      :secure => @secure
    }
  end
  def sstr
    @sstr
  end
  def _load(_sstr)
    return false unless _sstr and _sstr.size > 0
    (sid,mac) = _sstr.split(/_/)

    sid = sid.to_i
    return false if sid <= 0
    return false unless mac and mac.size > 0

    rec = @db[@table][:id => sid]
    return false unless rec and rec[:mac] == mac
    
    # timeout check
    updated = rec[:updated_at]
    return false if Time.now > (updated + @expire_after)
    
    @sstr = _sstr
    @hash = rec
    @sid = sid
    @mac = mac
    @loaded = true
    @cookies[@cookie_name] = cookie
    
    @db[@table].filter(:id => sid).update(:updated_at => 'now')

    true
  end
  def load_from_param(_sstr)
    _load(_sstr)
  end
  def load
    _sstr = @cookies[@cookie_name]
    _sstr = _sstr[0] if _sstr.is_a?(Array)
    _load(_sstr)
  end
  def create(hash = nil)
    @sid = @db[@table] << {}
    @mac = OpenSSL::Random.random_bytes(8).unpack('h*')[0]
    hash ||= {}
    @db[@table].filter(:id => @sid).update(hash.merge(:mac => @mac,:updated_at => Time.now))

    @sstr = "#@sid" + "_#@mac"
    @cookies[@cookie_name] = cookie
    @loaded = true

    true
  end
  def delete
    @cookies[@cookie_name] = {
      :value => nil,
      :expires => Time.now - 3600,
      :path => @path,
      :secure => @secure
    }
    @db[@table].filter(:id => @sid).delete
    @loaded = false
    true
  end
  def save
    return false unless @loaded
    [:updated_at, :mac, :id].each { |s| @hash.delete(s) }
    @db[@table].filter(:id => @sid).update(
      {:updated_at => Time.now}.merge(@hash)
    )
    true
  end
end
end # module
