
class Name
  Delimiter = '.'

  def self.split *args
    args
      .flatten
      .map{ _1.to_s.split Delimiter }
      .flatten
      .reject &:empty?
  end

  def set!(...)
    @me = self.class.split(...)
  end

  def initialize(...)
    set!(...)
  end

  # left-hand match
  # (empty object matches everything)
  def === o
    other = self.class.split o
    min = [@me.size, other.size].min
    @me.take(min) == other.take(min)
  end

  def to_a
    @me.clone
  end

  def to_s
    @me.empty? ? Delimiter : @me.join(Delimiter)
  end
  alias :inspect :to_s
  alias :to_str :to_s

  def hash
    to_s.hash
  end
end

