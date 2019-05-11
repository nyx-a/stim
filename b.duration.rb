
require_relative 'b.trap.rb'

class Duration
  UNIT = {
    'seconds'   => 1,
    'minutes'   => 60,
    'hours'     => 60 * 60,
    'days'      => 60 * 60 * 24,
  }
  ULBL,UVAL = UNIT.sort_by(&:last).reverse.transpose

  def self.unit str
    r = ULBL.find{ |k| k =~ /^#{str}/ }
    raise "unknown unit => '#{str}'" if r.nil?
    UNIT[r]
  end

  def self.string_to_second str
    bamboo = str.scan(/(\d+(?:\.\d+)?)\s*(\p{alpha}+)/)
    if bamboo.empty?
      return nil
    end
    sum = 0
    for a,u in bamboo
      sum += a.to_f * Duration.unit(u)
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

  def self.[] o, unit:nil, f:0
    Duration.new o, unit:unit, f:f
  end

  # ---

  def initialize o=nil, unit:nil, f:0
    self.store(o, unit:unit, f:f)
  end

  def store o, unit:nil, f:0
    self.fratio = f # fluctuation ratio
    @sec = if unit.nil?
             case o
             when NilClass then nil
             when String   then Duration.string_to_second o
             when Duration then o.second
             else
               raise "invalid class => '#{o.class}'"
             end
           else
             o * Duration.unit(unit)
           end
  end

  def to_s
    @sec.nil? ? '<empty>' : Duration.second_to_string(@sec)
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
    @sec.nil? ? nil : @sec / 60.0 / 60.0
  end
  def minute
    @sec.nil? ? nil : @sec / 60.0
  end
  def second
    @sec
  end

  def + other
    other = Duration.new(other)
    Duration.new(@sec + other.second, unit:'seconds')
  end
  def - other
    other = Duration.new(other)
    Duration.new(@sec - other.second, unit:'seconds')
  end
  def * other
    Duration.new(@sec * other, unit:'seconds')
  end
  def / other
    Duration.new(@sec / other, unit:'seconds')
  end
  def < other
    @sec < other.second
  end
  def > other
    @sec > other.second
  end
  def <= other
    @sec <= other.second
  end
  def >= other
    @sec >= other.second
  end
  def == other
    @sec == other.second
  end
  def <=> other
    @sec <=> other.second
  end
  def === other
    @sec === other.second
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
    Duration.new(self.to_f, unit:'seconds')
  end

  def sleep
    return true if Trap.interrupted
    ssec = self.to_f
    if ssec < 0
      raise "sleep interval must be positive => '#{ssec}'"
    end
    Trap.start { Kernel.sleep ssec }
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
