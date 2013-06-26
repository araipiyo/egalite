# Egalite support methods

class Hash
  def <<(b)
    merge(b.to_hash)
  end
  def >>(b)
    b.to_hash.merge(self)
  end
end

class NilClass #:nodoc:
  def size
    0
  end
end

# <<from ActiveSupport library of Ruby on Rails>>
# (MIT License)

# Tries to send the method only if object responds to it. Return +nil+ otherwise.
# 
# ==== Example :
# 
# # Without try
# @person ? @person.name : nil
# 
# With try
# @person.try(:name)
class Object
  def try(method)
    send(method) if respond_to?(method, true)
  end
end

