
module B
end

class B::Structure
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

  def to_hash k:'to_s', v:'itself'
    instance_variables.map do |n|
      [
        n[1..].send(k),
        instance_variable_get(n)&.send(v),
      ]
    end.to_h
  end

  def inspect indent:1
    longest = instance_variables.map(&:size).max - 1
    lines = instance_variables.map do |n|
      "#{' ' * indent}%-*s = %s" % [
        longest,
        n[1..],
        instance_variable_get(n).inspect,
      ]
    end.join "\n"
    "#{self.class.name} {\n#{lines}\n}"
  end
end

