class Hash
  def stringify_keys
    Hash[self.map{|key, val| [key.to_s, val]}]
  end

  def symbolize_keys
    Hash[self.map{|key, val| [key.to_sym, val]}]
  end
end
