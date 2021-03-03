
require_relative 'b.structure.rb'
require_relative 'b.enum.rb'
require_relative 'b.path.rb'

#
#* Why the output file does not exist
#

Absent = B::Enum.new :expire, :dup, :empty, :abduction

def Absent.funnel other, nilable:
  if other.nil?
    if nilable
      nil
    else
      raise 'nil cannot be passed through'
    end
  else
    other.is_a?(self) ? other : self.new(other.to_sym)
  end
end

#
#* A output file
#

class Output < B::Structure
  attr_reader :path   # B::Path
  attr_reader :size   # Integer
  attr_reader :absent # Absent or nil

  def absent?
    not @absent.nil?
  end

  def present?
    @absent.nil?
  end

  def initialize path:, size:, absent:nil
    @path   = B::Path.new path, confirm:nil
    @size   = size
    @absent = Absent.funnel absent, nilable:true
    if present?
      if @size.zero?
        unlink :empty
      elsif not @path.exist?
        @absent = Absent.new :abduction
      end
    end
  end

  def same_as o
    if present? and o.present?
      if @size!=0 and @size==o.size
        if @path.exist? and o.path.exist?
          @path.open('rb').read == o.path.open('rb').read
        end
      end
    end
  end

  def unlink r
    if present?
      @absent = Absent.funnel r, nilable:false
      @path.unlink
    end
  end

  def self.funnel other
    case other
    when self
      other
    when Hash
      self.new(**other.transform_keys(&:to_sym))
    else
      raise TypeError, "can't change #{other} to #{self}"
    end
  end
end

