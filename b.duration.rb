
require_relative 'b.trap.rb'

module B
  # for namespace
end

class B::Duration
  include Comparable

  UNIT = {
    'seconds'   => Float(           1),
    'minutes'   => Float(          60),
    'hours'     => Float(     60 * 60),
    'days'      => Float(24 * 60 * 60),
  }
  ULBL,UVAL = UNIT.sort_by(&:last).reverse.transpose

  def self.unit str
    r = ULBL.find{ |k| k =~ /^#{str}/ }
    raise "unknown unit => '#{str}'" if r.nil?
    UNIT[r]
  end

  def self.parse str
    B::Duration.new string_to_second str
  end

  def self.string_to_second str
    bamboo = str.scan(/(\d+(?:\.\d+)?)\s*(\p{alpha}+)/)
    if bamboo.empty?
      return nil
    end
    sum = 0
    for a,u in bamboo
      sum += a.to_f * B::Duration.unit(u)
    end
    return sum
  end

  def self.second_to_string sec
    if sec.nil?
      return nil
    end
    sign = sec < 0 ? '-' : ''
    result = [ ]
    remainder = UVAL.inject(sec.abs.rationalize) do |rest, unit|
      result.push (rest / unit).floor
      rest % unit
    end
    result[-1] += remainder.to_f unless remainder.zero?
    z = result.zip ULBL
    z.reject!{ |i| i[0].zero? }
    if z.empty?
      '0 second'
    else
      z.each{ |i| i[1]=i[1].chop if i[0]==1 }
      z.map!{ |i| "#{i[0].is_a?(Float) ? '%.1f' : '%d'} %s" % i }
      sign + z.join(' ')
    end
  end

  def self.[] *args
    B::Duration.new(*args)
  end

  # ---

  def initialize obj=nil, unit:nil, f:0
    self.store(obj, unit:unit, f:f)
  end

  def store obj, unit:nil, f:0
    self.fratio = f # fluctuation ratio
    @sec = if unit.nil?
             case obj
             when NilClass    then nil
             when String      then B::Duration.string_to_second obj
             when Numeric     then obj.to_f
             when B::Duration then obj.second
             else
               raise "invalid class => '#{obj.class}'"
             end
           else
             obj * B::Duration.unit(unit)
           end
  end

  def to_s
    @sec.nil? ? '<empty>' : B::Duration.second_to_string(@sec)
  end

  def inspect
    "#{self.to_s} (f:#{@fratio * 100}%)"
  end

  def empty?
    @sec.nil?
  end
  alias :blank? :empty?
  alias :invalid? :empty?

  def clear
    @sec = nil
  end
  alias :reset :clear

  def hour
    @sec.nil? ? nil : @sec / UNIT['hours']
  end
  def minute
    @sec.nil? ? nil : @sec / UNIT['minutes']
  end
  def second
    @sec
  end

  def + other
    B::Duration[@sec + B::Duration[other].second]
  end
  def - other
    B::Duration[@sec - B::Duration[other].second]
  end
  def * other
    B::Duration[@sec * B::Duration[other].second]
  end
  def / other
    B::Duration[@sec / B::Duration[other].second]
  end

  def <=> other
    @sec <=> B::Duration[other].second
  end

  # ---

  def fratio
    @fratio
  end
  def fratio= f
    if f<0 or 2<f
      raise RangeError, "out of range => '#{f}'"
    end
    @fratio = f
  end

  # ---

  def shake
    B::Duration.new self.to_f
  end

  def sleep
    return true if B::Trap.interrupted?
    ssec = self.to_f
    if ssec < 0
      raise "sleep interval must be positive => '#{ssec}'"
    end
    B::Trap.sleep ssec
  end

  def loop &block
    begin
      block.call
    end until self.sleep
  end

  def to_f
    s = @sec * @fratio
    r = Kernel.rand Range.new(*[s, 0.0].sort)
    return @sec - (s / 2) + r
  end
end
