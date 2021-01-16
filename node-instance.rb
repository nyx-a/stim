
require_relative 'node-class.rb'
require_relative 'b.dhms.rb'
require_relative 'tuple.rb'


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

  def initialize(...)
    super(...)
    @history = History.new register:@@capture + @name + '.yaml'
  end

  #
  #
  #

  def issue instr
    @@ts.write Stimulus[to:@name, instr:instr], TupleExpire
  end

  def report result
    @@ts.write Report[from:@name, result:result], TupleExpire
  end

  # <- tuple
  def wait time
    # Rinda::TupleSpace#take waits forever if it receives nil.
    @@ts.take Stimulus[to:@name], time
  end

  #
  #
  #

  def synchronize &b
    @mutex ? @mutex.synchronize(&b) : b.call
  end

  def pong
    report :pong
  end

  def run
    name = @name.to_s
    r = synchronize do
      @command.run @@capture, name do |r|
        @@log.i "START #{name} (#{r.pid})"
      end
    end
    @@log.public_send(
      (r.status==0 ? :i : :e),
      "END   #{name} (#{r.pid}) #{B.sec2dhms r.time_spent}"
    )
    @history.push r
    report r
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

  def revolve
    loop do
      begin
        tuple = Stimulus.new(**wait(@interval&.start))
      rescue Rinda::RequestExpiredError
        # Cyclic execution
        tuple = Stimulus.new instr: :execute
      end
      case tuple.instr.value
      when :execute then run
      when :pause   then pause
      when :resume  then resume
      when :ping    then pong
      when :eject   then break
      else
        @@log.e "Unknown instruction `#{tuple.instr}`"
      end
    end
  end

  def start_thread
    if @thread&.status
      @@log.e %Q`Thread is already running "#{@name}"`
      return @thread
    end
    @thread = Thread.new{ revolve }
    @thread.name = @name.to_s
    @@log.i %Q`Thread started "#{@name}"`
    nil
  end

  def wait_close
    @thread&.join
    @history.save
  end

end

