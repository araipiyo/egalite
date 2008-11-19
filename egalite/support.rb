# Egalite support methods

class Hash
  def <<(b)
    merge(b.to_hash)
  end
  def >>(b)
    b.to_hash.merge(self)
  end
end

