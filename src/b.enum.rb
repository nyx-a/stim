
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
    @value
  end

  def set! v
    p = self.class.const_get :POSSIBLE
    if p.any?{ _1 == v }
      @value = v.clone.freeze
    else
      raise KeyError, "Invalid key `#{v}` for enum #{p}"
    end
    return self
  end

  def inspect
    body = self.class.const_get(:POSSIBLE).map do |x|
      i = x.inspect
      x==@value ? "[#{i}]" : i
    end.join ' '
    "#{self.class.name}( #{body} )"
  end

  def operator_N *args, &block
    @value.public_send(__callee__, *args, &block)
  end

  def operator_1 arg, &block
    arg = arg.value if arg.is_a? self.class # peel
    @value.public_send(__callee__, arg, &block)
  end

  alias :to_i    :operator_N
  alias :to_f    :operator_N
  alias :to_s    :operator_N
  alias :to_sym  :operator_N
  alias :to_proc :operator_N
  alias :==      :operator_1
  alias :===     :operator_1

  undef :operator_N
  undef :operator_1
end

