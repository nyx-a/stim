
module B
end

class B::Boolean
  def self.parse s
    case s
    when true,  /^\s*(?:t|true |on |yes)\s*$/ix; true
    when false, /^\s*(?:f|false|off|no )\s*$/ix; false
    else
      raise "Doesn't look like a Boolean `#{s}`"
    end
  end

  def initialize s
    @b = self.class.parse s
  end

  def on!
    @b = true
  end

  def off!
    @b = false
  end

  def toggle!
    @b = !@b
  end

  def to_b # to built-in
    @b
  end

  def to_s
    @b ? 'True' : 'False'
  end

  def inspect
    to_s
  end
end

