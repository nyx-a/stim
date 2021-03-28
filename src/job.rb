
require_relative 'b.dhms.rb'
require_relative 'command.rb'
require_relative 'history.rb'
require_relative 'pendulum.rb'

class Job

  @@mtx = { } # { ? => Mutex }

  def self.dispense_mutex token
    if token.nil?
      nil
    else
      token = token.to_s
      @@mtx.fetch(token){ @@mtx[token] = Mutex.new }
    end
  end

  def self.capture= o
    @@capture = o
  end

  def self.log= o
    @@log = o
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :name     # Name
  attr_reader :interval # Numeric
  attr_reader :mutex    # Mutex
  attr_reader :command  # Command

  def name= *o
    @name = Name.new(*o)
  end

  def interval= o
    @interval = case o
                when nil     then nil
                when String  then B.dhms2sec o
                when Numeric then o
                else
                  raise TypeError, "#{o}(#{o.class})"
                end
  end

  def mutex= token
    @mutex = self.class.dispense_mutex token
  end

  def initialize(
    name:,
    interval:  nil,
    mutex:     nil,
    directory: nil,
    command:,
    option:    nil
  )
    self.interval = interval
    self.mutex    = mutex
    self.name     = name
    @command = Command.new(
      directory: directory,
      command:   command,
      option:    option,
    )
    @history = History.new @@capture + @name + '.yaml'
    @pendulum = Pendulum.new @interval, self
    @pendulum.start
    @@log.i "#{@name} started"
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def synchronize &b
    @mutex ? @mutex.synchronize(&b) : b.call
  end

  def call
    name = @name.to_s
    r = synchronize do
      @command.run @@capture, name do |r|
        @@log.i "START #{name} (#{r.pid})"
      end
    end
    @@log.send(
      (r.status==0 ? :i : :e),
      "END   #{name} (#{r.pid}) #{B.sec2dhms r.time_spent}"
    )
    @history.push r
    return nil
  end

  def execute
    case
    when @pendulum.dead?
      self.call
      @pendulum.reset
      @@log.i "#{@name} executed only once"
    when @pendulum.sleeping?
      @pendulum.stop
      @pendulum.start 0
      @@log.i "#{@name} executed immediately and the cycle was reset"
    else
      @@log.i "#{@name} now #{@pendulum.state}"
    end
  end

  def pause
    if @pendulum.pause
      @@log.i "#{@name} going to pause (#{remaining_time})"
    else
      @@log.i "#{@name} already pausing"
    end
  end

  def resume
    if @pendulum.start
      @@log.i "#{@name} Resumed (#{remaining_time})"
    else
      @@log.i "#{@name} already starting"
    end
  end

  def terminate
    @pendulum.stop
    @pendulum.join
    @history.save
    @@log.i "#{@name} terminated"
  end

  def state
    @pendulum.state
  end

  def remaining_time
    rt = @pendulum.remaining_time
    if rt
      Time.at(rt, in:'UTC').strftime("%k:%M:%S")
    end
  end

end

