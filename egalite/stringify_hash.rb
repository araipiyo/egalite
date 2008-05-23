# used with http parameters
# simpler version of HashWithIndifferentAccess of Ruby on Rails

module Egalite
class StringifyHash < Hash
  def self.create(values)
    hash = self.new
    hash.update(values)
    hash
  end
  def [](k)
    super(stringify(k))
  end
  def []=(k,v)
    super(stringify(k),v)
  end
  def update(hash)
    newhash = {}
    hash.each { |k,v|
      newhash[stringify(k)] = v
    }
    super(newhash)
  end
  alias_method :merge!, :update

  def key?(key)
    super(stringify(key))
  end

  alias_method :include?, :key?
  alias_method :has_key?, :key?
  alias_method :member?, :key?

  def fetch(key, *extras)
    super(convert_key(key), *extras)
  end

  def values_at(*indices)
    indices.collect {|key| self[convert_key(key)]}
  end

  def dup
    self.create(self)
  end

  def merge(hash)
    self.dup.update(hash)
  end

  def delete(key)
    super(stringify(key))
  end

  # Convert to a Hash with String keys.
  def to_hash
    Hash.new(default).merge(self)
  end
private
  def stringify(key)
    key.kind_of?(Symbol) ? key.to_s : key
  end
end
end
