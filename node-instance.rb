
require_relative 'node-class.rb'
require_relative 'b.dhms.rb'
require_relative 'tuple.rb'

#
#
#

class Node < B::Structure

  attr_reader :name     # Name
  attr_reader :command  # Command
  attr_reader :interval # Numeric
  attr_reader :mutex    # Mutex

  def name= *o
    @name = Name.new(*o)
  end

  def command= o
    raise TypeError, o.class unless o.is_a? Command
    @command = o
  end

  def interval= o
    @interval = case o
                when nil     then nil
                when String  then Timekeeper.new B.dhms2sec o
                when Numeric then Timekeeper.new o
                else
                  raise TypeError, "#{o}(#{o.class})"
                end
  end

  def mutex= token
    @mutex = self.class.get_mutex token
  end

  #
  #
  #

  def save_history path
    @history.save_file path
  end

  def load_history path
    @history.load_file path
  end

  def synchronize &b
    @mutex ? @mutex.synchronize(&b) : b.call
  end

  def pong
    @@ts.write Report[from:@name, result: :pong], TupleExpire
  end

  def run
    name = @name.to_s
    r = synchronize do
      @command.run @@capture, name do |r|
        @@log.i "START #{@family} #{name} (#{r.pid})"
      end
    end
    @@log.public_send(
      (r.status==0 ? :i : :e),
      "END   #{name} (#{r.pid}) #{B.sec2dhms r.time_spent}"
    )
    @history.push r
    @@ts.write Report[from:@name, result:r], TupleExpire
    @interval&.reset
    return r
  end

  def pause
    if @interval&.active?
      left = @interval&.pause
      str = left ? " (#{B.sec2dhms left} left)" : ''
      @@log.i "PAUSE #{@name}#{str}"
    else
      @@log.w "Already pausing. #{@name}"
    end
  end

  def resume
    if @interval&.active?
      @@log.w "Already active. #{@name}"
    else
      left = @interval&.start
      str = left ? " (#{B.sec2dhms left} remaining)" : ''
      @@log.i "RESUME #{@name}#{str}"
    end
  end

  def loop
    loop do
      left = @interval&.start
      begin
        # Rinda::TupleSpace#take waits forever if it receives nil.
        tuple = @@ts.take Stimulus[to:@name], left
      rescue Rinda::RequestExpiredError
        # Cyclic execution
        tuple = Stimulus[ instr: :execute ]
      end
      case tuple.instr
      when :execute then run
      when :pause   then pause
      when :resume  then resume
      when :ping    then pong
      when :eject   then break
      else
        @log.e "Unknown instruction `#{tuple.instr}`"
      end
    end
  end

  def start_thread
    if @thread&.status
      @@log.e %Q`Thread is already running "#{@name}"`
      return @thread
    end
    @thread = Thread.new{ loop }
    @thread.name = @name.to_s
    @@log.i %Q`Thread started "#{@name}"`
    nil
  end

  def join_thread
    @thread&.join
  end

end

