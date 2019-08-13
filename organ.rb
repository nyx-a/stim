
module B
  def equal o
    -> x { x === o }
  end
end

class B::Organ
  def initialize **hash
    for k,v in hash
      unless self.class.method_defined? k
        raise "Unallowed key `#{k}`"
      end
      instance_variable_set "@#{k}", v
    end
  end

  def hash
    instance_variables.map{ |n|
      instance_variable_get n
    }.hash
  end

  def inspect_h
    instance_variables.to_h do |name|
      [name[1..], instance_variable_get(name).inspect]
    end
  end

  def inspect
    ml = inspect_h.keys.map(&:length).max
    inspect_h.map { |k,v|
      "%-*s - %s" % [ml, k, v]
    }.join "\n"
  end
end
