
module B
  # B is the B of BAKA.
end

class B::Structure

  def clear padding=nil
    for sym in public_methods(false).grep(/(?<!=)=$/)
      instance_variable_set "@#{sym[..-2]}", padding
    end
    return self
  end

  def initialize(...)
    clear
    insert(...)
  end

  def insert **hash
    for k,v in hash
      sym = "#{k}=".to_sym
      if respond_to? sym
        self.send sym, v
      else
        raise KeyError, "Unknown element #{k.inspect}"
      end
    end
    return self
  end

  #
  # be similar to Hash
  #

  def merge *others
    others.inject self.clone do |a,b|
      a.insert b
    end
  end
  alias :overlay :merge

  def keys m=:to_sym
    instance_variables.map{ _1[1..].send m }
  end

  def slice *keep
    c = self.clone
    for x in self.keys - keep.flatten.map(&:to_sym)
      c.instance_variable_set "@#{x}", nil
    end
    return c
  end

  def mask *hide
    c = self.clone
    for x in self.keys & hide.flatten.map(&:to_sym)
      c.instance_variable_set "@#{x}", nil
    end
    return c
  end

  def to_a k:'to_sym', v:'itself', recur:false
    instance_variables.map do |n|
      value = instance_variable_get n
      if recur and value.kind_of? B::Structure
        value = value.to_a k:k, v:v, recur:recur
      end
      [ n[1..].public_send(k), value&.public_send(v) ]
    end
  end

  def each k:'to_sym', v:'itself', recur:false, &b
    to_a(k:k,v:v,recur:recur).send(__callee__, &b)
  end
  alias :map :each

  # It's __method__, not __callee__.
  # Cause Array doesn't have to_hash method.
  def to_h k:'to_sym', v:'itself', recur:true, &b
    to_a(k:k,v:v,recur:recur).send(__method__, &b)
  end
  alias :to_hash :to_h

  #
  # inspector
  #

  INDENT = 2

  def inspect indent:INDENT
    "<<#{self.class.name}>>\n" + self.map do |k,v|
      i = if v.is_a? B::Structure
            v.inspect(indent: indent + INDENT)
          else
            v.inspect
          end
      "#{' ' * indent}#{k} = #{i}"
    end.join("\n")
  end

end

