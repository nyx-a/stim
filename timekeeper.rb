
class Timekeeper
  def initialize sec
    @reference = sec
    @length = nil
    @start = nil
  end

  def active?
    not @start.nil?
  end

  def start # also a resume
    if @start.nil?
      if @length.nil? or @length.negative?
        @length = @reference
      end
      @start = Time.now
      @length
    end
  end

  def pause
    if @start
      if @length
        @length -= Time.now - @start
      end
      @start = nil
      @length
    end
  end

  def reset
    @length = nil
    @start  = nil
  end
end

