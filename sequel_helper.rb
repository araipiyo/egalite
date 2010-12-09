
class Sequel::Model
  def update_with(hash, *selection)
    data = {}
    selection.flatten.each { |k| data[k] = hash[k] || hash[k.to_sym] }
    update(data)
  end
  def update_without(hash, *selection)
    selection.flatten.each { |k| hash.delete(k.to_s) if hash[k.to_s] }
    selection.flatten.each { |k| hash.delete(k.to_sym) if hash[k.to_sym] }
    update(hash)
  end
  def to_hash
    hash = {}
    self.each { |k,v| hash[k] = v }
    hash
  end
end

