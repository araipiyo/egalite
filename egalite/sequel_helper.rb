
class Sequel::Model
  def update_with(hash, *selection)
    data = {}
    selection.flatten.each { |k| data[k] = hash[k] || hash[k.to_sym] }
    update_with_params(data)
  end
  def update_without(hash, *selection)
    selection.flatten.each { |k| hash.delete(k) if hash[k] }
    selection.flatten.each { |k| hash.delete(k.to_sym) if hash[k.to_sym] }
    update_with_params(hash)
  end
end

