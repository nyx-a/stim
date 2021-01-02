
module B
  class DHMS
    # These constants are plural for a reason.
    DAYS    = 60 * 60 * 24
    HOURS   = 60 * 60
    MINUTES = 60
    SECONDS = 1

    def self.intro_quiz s
      match = constants.grep %r/^#{Regexp.escape s}/i
      match.one? ? match.first : nil
    end
  end

  extend self

  # String -> Float
  def dhms2sec str
    sec     = 0
    onetime = [ ]
    clone   = str.clone
    while clone.sub!(/(\-?\d+(?:\.\d+)?)\s*(\p{alpha}+)/, '')
      a = $1
      u = $2
      unit = B::DHMS.intro_quiz u
      if unit.nil?
        raise ArgumentError, "Invalid unit #{u} (#{str})"
      end
      if onetime.any? unit
        raise ArgumentError, "Duplicated unit #{u} (#{str})"
      else
        onetime.push unit
      end
      sec += a.to_f * B::DHMS.const_get(unit)
    end
    clone.strip!
    unless clone.empty?
      raise ArgumentError, "Extra part #{clone} (#{str})"
    end
    return sec
  end

  # Numeric -> String
  def sec2dhms num
    r   = num
    d,r = r.divmod B::DHMS::DAYS
    h,r = r.divmod B::DHMS::HOURS
    m,r = r.divmod B::DHMS::MINUTES
    s   = r
    [
      d==0 ? '' : "#{d}d",
      h==0 ? '' : "#{h}h",
      m==0 ? '' : "#{m}m",
      s==0 ? '' : "#{s.round}s",
    ].join
  end
end

