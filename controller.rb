
require 'drb/drb'
require 'rinda/tuplespace'
require 'yaml'
require_relative 'b.cdcmd.rb'
require_relative 'b.cappedarray.rb'
require_relative 'b.structure.rb'
require_relative 'b.timelength.rb'


class Job
  include B::Structure
  attr_accessor :is_active   # Boolean
  attr_accessor :cdcmd       # CDCMD
  attr_accessor :interval    # Integer
  attr_accessor :sleep       # Integer
  attr_accessor :history     # CappedArray[ CDCMD::Result ]
  attr_accessor :thread      # Thread
end

class Stimulant
  include B::Structure
  attr_accessor :id          # "identifier"
  attr_accessor :direction   # %i(inbound outbound)
  attr_accessor :instruction # %i(eject pause resume)
  attr_accessor :result      # CDCMD::Result

  WILDCARD = self.new.to_hash.freeze

  # syntax sugar
  def self.[] **x
    self.new(**x).to_hash
  end
  def self.wildcard
    WILDCARD
  end
end


class Controller
  attr_reader :tuplespace
  attr_reader :historylimit # Integer
  attr_reader :pool         # String
  attr_reader :job          # Hash { 'id' => Job }
  attr_reader :bindip
  attr_reader :port
  attr_reader :home

  def initialize pool, historylimit, log, bindip, port, home
    @tuplespace   = Rinda::TupleSpace.new 15 # affects expire
    @historylimit = historylimit
    @pool         = B::Path.new(pool).prepare_dir!
    @job          = { }
    @log          = log
    @bindip       = bindip
    @port         = port
    @home         = home
    uri           = "druby://#{@bindip}:#{@port}"
    DRb.start_service uri, self
    log.i %Q`#{self.class} is ready at "#{DRb.uri}"`
    start_observer
  end

  def load filename
    path = B::Path.new(filename).expand! @home
    @log.i "Loading configure file: '#{path}'"
    raise "#{filename} doesn't exist" unless path.exist?
    for id,hash in YAML.load_file path.to_s
      add(
        id: id,
        d:  hash['d'],
        c:  hash['c'],
        o:  hash['o'],
        i:  B::TimeLength.parse(hash['t']),
      )
    end
    @job.keys
  end

  def reload filename
  end

  def add id:'', d:'.', c:, o:'', i:nil
    @job[id] = Job.new(
      is_active: true,
      interval:  i,
      history:   B::CappedArray.new(@historylimit),
      cdcmd:     B::CDCMD.new(
        tag:       id,
        capture:   @pool,
        directory: d,
        command:   c,
        option:    o,
      ),
    )
    start_thread id
  end

  def execute id, duration:3600
    result = @job[id].cdcmd.run do |pid, token|
      @log.i "START #{id} (#{pid},#{token})"
    end
    ts_s = B::TimeLength.sec_to_hms result.time_spent

    m = result.status==0 ? :i : :e
    @log.send m, "END   #{id} (pid:#{result.pid}) #{ts_s}"
    @job[id].history.push result
    tuple = Stimulant[
      id:        id,
      direction: :outbound,
      result:    result,
    ]
    @tuplespace.write tuple, duration
  end

  def send_eject pattern=//
    send_event :eject, pattern
  end

  def send_pause pattern=//
    send_event :pause, pattern
  end

  def send_resume pattern=//
    send_event :resume, pattern
  end

  def send_run pattern=//
    send_event :hand_execution, pattern
  end

  def send_event command, pattern=//
    for identifier in @job.keys.grep pattern
      @tuplespace.write Stimulant[
        id:          identifier,
        direction:   :inbound,
        instruction: command,
      ]
    end
  end

  def running
    @job.keys.select do |id|
      @job[id].cdcmd.is_running?
    end
  end

  def bootstrap
    for id,job in @job
      unless job.interval.nil?
        send_run id
        Kernel.sleep 1
      end
    end
  end

  def stop_thread id
    send_eject id
    @job[id]&.thread&.join
  end

  def pause_all
    @job.keys.each { |id| send_pause id }
  end

  def resume_all
    @job.keys.each { |id| send_resume id }
  end

  def eject_all
    @job.keys.each { |id| send_eject id }
  end

  def join_all
    @job.keys.each { |id| @job[id]&.thread&.join }
  end

  def stop_all
    eject_all
    join_all
  end

  # not running yet -> nil
  def seconds_since_last id
    t = @job[id].history&.last&.time_end
    if t
      Time.now - t
    end
  end

  def seconds_until_next id
    t = seconds_since_last(id) || Time.now
    n = @job[id].sleep || @job[id].interval
    if n
      n - t
    end
  end

  def echo
    @tuplespace.read_all Stimulant.wildcard
  end

  def history
    @job.values.map(&:history).flatten.sort_by(&:time_end)
  end

  def sleep
    @sleeper = Thread.new { Kernel.sleep }
    Signal.trap(:INT ) { @sleeper.run.join }
    Signal.trap(:TERM) { @sleeper.run.join }
    @sleeper.join
    @log.i 'Signal INT/TERM trapped.'
  end

  def wake
    @sleeper.run.join
  end

  def inspect
    [
      "History limit: #{@historylimit.inspect}",
      "Pool directory: #{@pool.inspect}",
      "Tuplespace bind IP: #{@bindip.inspect}",
      "Tuplespace port: #{@port.inspect}",
      "Job:",
      @job.map { |k,v|
        "[#{k}]\n#{v.inspect.gsub(/^/, '  ')}"
      }.join("\n").gsub(/^/, '  ')
    ].join "\n"
  end

  private

  def shake i, c=0.3
    return nil if i.nil?
    i + i * c * rand(-1.0..1.0)
  end

  def start_observer
    ob = Thread.new do
      observer = @tuplespace.notify nil, Stimulant.wildcard
      for event,tuple in observer
        @log.d "#{event} #{tuple.inspect}"
      end
    end
    ob.name = 'TuplespaceObserver'
  end

  def start_thread identifier
    t = Thread.new identifier do |id|
      patt = Stimulant[id:id, direction: :inbound]
      loop do
        tuple = if @job[id].is_active
                  begin
                    @job[id].sleep = shake @job[id].interval
                    @tuplespace.take patt, @job[id].sleep
                  rescue Rinda::RequestExpiredError
                    patt.merge(
                      'instruction' => :cyclic_execution
                    )
                  end
                else
                  @tuplespace.take patt.merge(
                    'instruction' => /eject|resume|pause/
                  )
                end
        case tuple['instruction']
        when :eject
          @job.delete id
          break
        when :pause
          @job[id].is_active = false
          @log.i "[Pause] #{id}"
        when :resume
          @job[id].is_active = true
          @log.i "[Resume] #{id}"
        else
          execute id
        end
      end
      @log.i %Q`Thread terminated "#{id}"`
    end
    t.name = identifier
    @job[identifier].thread = t
    @log.i %Q`Thread started "#{identifier}"`
    t
  end
end

