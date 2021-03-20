
require_relative 'name.rb'
require_relative 'b.enum.rb'
require_relative 'b.structure.rb'

class Tuple < B::Structure
  def self.wildcard
    self.new.to_h
  end
  def to_h
    super k:'to_s', v:->{ _1&.to_s }
  end
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Instruction = B::Enum.new(
  :execute, :pause, :resume, :eject,
)

class Stimulus < Tuple
  attr_reader :to
  attr_reader :instr

  def to= o
    @to = o ? Name.new(o) : nil
  end

  def instr= o
    @instr = o ? Instruction.new(o.to_sym) : nil
  end

  def inspect
    "To( #{@to.to_s} ) #{@instr.inspect}"
  end
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

class Report < Tuple
  attr_reader :from
  attr_reader :result

  def from= o
    @from = o ? Name.new(o) : nil
  end

  def result= o
    @result = o # should be a Result object
  end

  def inspect
    "From( #{@from.to_s} ) #{@result.inspect}"
  end
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

CTRL = B::Enum.new(
  :recipes, :nodes, :reload,
)

class Control < Tuple
  attr_reader   :ctrl
  attr_accessor :args

  def ctrl= o
    @ctrl = o ? CTRL.new(o) : nil
  end
end

