
# Interruptable Loop Timer
#
# - All relative times are expressed in seconds.
# - There are 5 states.
#     Default  : Dead  & full interval time   -> S
#     Pausing  : Dead  & remaining_time       -> S
#     Sleeping : Alive & sleeping             -> C,P
#     Calling  : Alive & calling              -> S,A
#     Aborting : Alive & calling & going dead -> D
#     ?        : Dead  & calling

class Pendulum
  def initialize interval, proc
    @interval = interval # Numeric or nil
    @proc     = proc     # Proc, Method or something
    @target   = nil      # Time - scheduled call time
    @began    = nil      # Time - call has started
    @ended    = nil      # Time - call has ended
    @broke    = nil      # Time - Interrupt moment

    if @interval.negative?
      raise ArgumentError,
        "it must not be negative -> #{@interval.inspect}"
    end
    unless @proc.respond_to? :call
      raise ArgumentError,
        "it must have a call() method -> #{proc.inspect}"
    end
  end

  def dead?
    !alive?
  end

  def alive?
    @thread&.alive?
  end

  def default?
    dead? and @broke.nil?
  end

  def pausing?
    dead? and @broke
  end

  def sleeping?
    alive? and !calling?
  end

  def calling?
    if @began
      if @ended
        @began > @ended
      else
        true
      end
    end
  end

  def aborting?
    alive? and calling? and @broke
  end

  def target = @target.clone
  def began  = @began.clone
  def ended  = @ended.clone
  def broke  = @broke.clone

  def remaining_time
    case
    when default?  then @interval
    when pausing?  then @target &.- @broke
    when sleeping? then @target &.- Time.now
    end
  end

  def elapsed_time
    if calling?
      Time.now - @began
    end
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def start sec=nil
    if alive?
      return false
      # raise "Multiple activation is not allowed."
    end
    if sec.nil?
      sec = remaining_time
      if sec.nil?
        sec = @interval
      end
    end
    if sec.negative?
      raise ArgumentError,
        "it must not be negative -> #{sec.inspect}"
    end

    @broke = nil
    @thread = Thread.new do
      loop do
        @target = Time.now + sec
        sleep sec # interruptable
        if @broke
          break
        end
        #<
        @began = Time.now
        @proc.call
        @ended = Time.now
        #>
        if @broke
          @target = @broke = nil
          break
        end
        sec = @interval
      end
    end
    return true
  end

  def stop
    if alive?
      @broke = Time.now
      @thread.run
      return true
    end
  end

  alias :resume :start
  alias :pause  :stop

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def reset
    case
    when pausing?
      @target = @broke = nil
    when sleeping?
      stop
      @target = @broke = nil
      start
    end
  end

  def join
    @thread.join
    return nil
  end

  def state
    %w(dead alive default pausing sleeping calling aborting)
      .select{ send "#{_1}?" }
      .join('+')
  end

  def inspect
    p = %w(dead alive default pausing sleeping calling aborting)
      .select{ send "#{_1}?" }

    v = %w(interval target began ended broke)
      .map{
        x = instance_variable_get "@#{_1}"
        x.nil? ? nil : "#{_1}=#{x}"
      }
      .compact

    m = %w(remaining_time elapsed_time)
      .map{
        x = send _1
        x.nil? ? nil : "#{_1}=#{x}"
      }
      .compact

    "#{p.inspect}\n#{v.inspect}\n#{m.inspect}"
  end
end

