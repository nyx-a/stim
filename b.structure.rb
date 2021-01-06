
module B
  def self.callablize object
    case
    when object.respond_to?(:call)
      object
    when object.respond_to?(:to_proc)
      object.to_proc
    when object.respond_to?(:to_sym)
      object.to_sym.to_proc
    else
      raise "Can't make it callable #{object}(#{object.class})"
    end
  end
end

class B::Structure
  # Recursive
  def self.to_h structure, k:'to_sym', v:'itself'
    structure.to_h do |key,value|
      key = B.callablize(k).call key
      value = if value.is_a? B::Structure
                to_h value, k:k, v:v
              else
                B.callablize(v).call value
              end
      [key, value]
    end
  end

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

  def merge *others
    others.inject self.clone do |a,b|
      a.insert b
    end
  end
  alias :overlay :merge

  def keys m=:to_sym
    instance_variables.map{ B.callablize(m).call _1[1..] }
  end

  def slice *keep
    c = self.clone
    for x in self.keys - keep.flatten.map(&:to_sym)
      c.instance_variable_set "@#{x}", nil
    end
    return c
  end

  def except *hide
    c = self.clone
    for x in self.keys & hide.flatten.map(&:to_sym)
      c.instance_variable_set "@#{x}", nil
    end
    return c
  end
  alias :mask :except

  def to_a k:'to_sym', v:'itself'
    instance_variables.map do |key|
      [
        B.callablize(k).call(key[1..]),
        B.callablize(v).call(instance_variable_get(key)),
      ]
    end
  end

  def map k:'to_sym', v:'itself', &b
    to_a(k:k, v:v).map(&b)
  end

  def to_h k:'to_sym', v:'itself', &b
    to_a(k:k, v:v).to_h(&b)
  end

  def to_hash(...)
    to_h(...)
  end

  def inspect indent:2
    stuff = self.map do |k,v|
      i = v.is_a?(B::Structure) ? v.inspect(indent:indent) : v.inspect
      "#{k} = #{i}"
    end.join("\n").gsub(/^/, ' '*indent)
    "<#{self.class.name}>\n#{stuff}"
  end
end

