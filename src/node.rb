
require_relative 'timekeeper.rb'
require_relative 'b.dhms.rb'
require_relative 'tuple.rb'
require_relative 'history.rb'

class Node

  @@mtx = { } # { ? => Mutex }

  def self.get_mutex token
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

  def self.ts= o
    @@ts = o
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
                when String  then Timekeeper.new B.dhms2sec o
                when Numeric then Timekeeper.new o
                else
                  raise TypeError, "#{o}(#{o.class})"
                end
  end

  def mutex= token
    @mutex = self.class.get_mutex token
  end

  def initialize(
    name:,
    interval:  nil,
    mutex:     nil,
    directory: nil,
    command:,
    option:    nil
  )
    @command = Command.new(
      directory: directory,
      command:   command,
      option:    option,
    )
    self.interval = interval
    self.mutex    = mutex
    self.name     = name
    @history = History.new register:@@capture + @name + '.yaml'
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

  def execute
    @thread = Thread.start { run }
  end

  def run
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

  def eject
    @thread.join
    @history.save
  end

end

