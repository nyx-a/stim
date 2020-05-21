
module OrganicStructure
  def clear padding=nil
    for sym in public_methods(false).grep(/(?<!=)=$/)
      instance_variable_set "@#{sym.to_s.chop}", padding
    end
  end

  def initialize **arg
    clear
    for k,v in arg
      sym = "#{k}=".to_sym
      if respond_to? sym
        sym.to_proc[self, v]
      else
        raise KeyError, "Unknown element #{k.inspect}"
      end
    end
  end

  def to_hash
    instance_variables.map do |n|
      [ n[1..], instance_variable_get(n) ]
    end.to_h
  end

  def inspect
    self.class.name + to_hash.inspect
  end
end

