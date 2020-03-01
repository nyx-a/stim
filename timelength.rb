
module B
  # prepare namespace
end

class B::TimeLength
  include Comparable

  def self.coefficient s
    patt = /^#{Regexp.escape s}/i
    case
    when patt =~ 'days'    then 60 * 60 * 24
    when patt =~ 'hours'   then 60 * 60
    when patt =~ 'minutes' then 60
    when patt =~ 'seconds' then 1
    else
      raise "Unknown unit `#{s}`"
    end
  end

  def self.sec_to_hms r
    d,r = r.divmod 86400
    h,r = r.divmod 3600
    m,r = r.divmod 60
    s   = r
    hms = (h==0 ? '' : "#{h}:") + ('%02d:%02d' % [m, s.floor])
    day =  d==0 ? '' : "#{d}day" + (d > 1 ? 's' : '')
    if d.zero?
      hms
    elsif [h,m,s].all? &:zero?
      day
    else
      "#{day} + #{hms}"
    end
  end

  def self.parse string
    pairs = string.scan(/(\d+(?:\.\d+)?)\s*(\p{alpha}+)/)
    if pairs.empty?
      raise "Does not contain valid time `#{string}`"
    end
    sec = 0
    for a,u in pairs
      sec += a.to_f * self.coefficient(u)
    end
    sec
  end

  attr_reader :sec
  alias :to_i :sec

  def initialize other
    case other
    when String
      self.parse other
    when Numeric
      @sec = other.to_f
    else
      raise "Invalid type `#{other.class}`"
    end
    self
  end

  def to_s
    self.class.sec_to_hms @sec
  end

  def parse string
    @sec = self.class.parse string
  end

  def inspect
    self.to_s
  end

  def <=> other
    @sec <=> other.sec
  end
end
