
module B
end

class B::CappedArray < Array
  attr_accessor :limit
  attr_accessor :destructor

  def initialize l, d=nil
    @limit      = l
    @destructor = d
  end

  def push o
    if @destructor and @limit <= self.size
      @destructor.to_proc[self.shift]
    end
    super
  end

  def unshift o
    if @destructor and @limit <= self.size
      @destructor.to_proc[self.pop]
    end
    super
  end
end

