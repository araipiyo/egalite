
class Sequel::Model
  def update_select(selection, hash)
    data = {}
    selection.each { |k| data[k] = hash[k] || hash[k.to_sym] }
    update_with_params(data)
  end
end

