
class CappedArray < Array
  attr_accessor :limit
  attr_accessor :destructor

  def initialize l, d
    @limit      = l
    @destructor = d
  end

  def push o
    if @limit <= self.size
      @destructor.to_proc[self.shift]
    end
    super
  end

  def unshift o
    if @limit <= self.size
      @destructor.to_proc[self.pop]
    end
    super
  end
end

