
class Sequel::Model
  def update_selection_only(hash, selection)
    data = {}
    selection.each { |k| data[k] = hash[k] || hash[k.to_sym] }
    update_with_params(data)
  end
  def update_selection_except(hash, selection)
    selection.each { |k| hash.delete(k) if hash[k] }
    update_with_params(hash)
  end
end

