
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
      value = instance_variable_get n
      if value.kind_of? B::Structure
        value = value.to_hash k:k, v:v
      end
      [n[1..].public_send(k), value&.public_send(v)]
    end.to_h
  end

  INDENT = 2

  def inspect indent:INDENT
    lines = instance_variables.map do |n|
      value = instance_variable_get n
      str = if value.kind_of? B::Structure
              value.inspect(indent: indent + INDENT)
            else
              value.inspect
            end
      "#{' ' * indent}%s = %s" % [n[1..], str]
    end.join "\n"
    "<<#{self.class.name}>>\n#{lines}"
  end
end

