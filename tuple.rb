
require_relative 'command.rb'
require_relative 'b.structure.rb'
require_relative 'b.enum.rb'


class Name
  Delimiter = '.'

  def self.resolve *o
    o = o.flatten.map &:to_s
    raise ArgumentError, o.inspect if o.any? &:empty?
    o.map{ _1.split Delimiter }.flatten
  end

  def set! *o
    @me = self.class.resolve o
  end

  def initialize *o
    set! o
  end

  # left-hand match
  # (empty object matches everything)
  def === o
    other = self.class.resolve o
    min = [@me.size, other.size].min
    @me.take(min) == other.take(min)
  end

  def to_s
    @me.join Delimiter
  end
  alias :inspect :to_s
  alias :to_str :to_s

  def hash
    to_s.hash
  end
end

#
#
#

Instruction = B::Enum.new(
  :execute, :pause, :resume, :eject, :ping,
)

temporaryModule = Module.new do
  def wildcard
    self.new.to_h k:'to_s'
  end
  def [](...)
    self.new(...).to_h k:'to_s'
  end
end

Stimulus = Class.new B::Structure do
  extend temporaryModule
  attr_reader :to
  attr_reader :instr

  def to= o
    @to = Name.new o
  end

  def instr= o
    @instr = Instruction.new o.to_sym
  end
end

Report = Class.new B::Structure do
  extend temporaryModule
  attr_reader :from
  attr_reader :result

  def from= o
    @from = Name.new o
  end

  def result= o
    raise unless o.is_a? Result
    @result = o
  end
end

