
module B
  # B is a initial letter of Baka.
end

class B::Enum
  def self.new *c
    Class.new self do
      self.const_set :POSSIBLE, c
      def self.new v
        e = self.allocate
        e.set! v
      end
    end
  end

  def value
    @value.clone
  end

  def set! v
    p = self.class.const_get :POSSIBLE
    if p.any?{ _1 == v }
      @value = v
    else
      raise TypeError, "Invalid key `#{v}` for enum #{p}"
    end
    return self
  end

  def == other
    @value == other
  end
  alias :=== :==

  def inspect
    body = self.class.const_get(:POSSIBLE).map do |x|
      i = x.inspect
      x==@value ? "[#{i}]" : i
    end.join ' '
    "#{self.class.name}( #{body} )"
  end
end

