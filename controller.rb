
require 'drb/drb'
require 'rinda/tuplespace'
require 'yaml'
require_relative 'cdcmd.rb'
require_relative 'os.rb'
require_relative 'ca.rb'
require_relative 'timelength.rb'


class Job
  include OrganicStructure
  attr_accessor :is_active   # Boolean
  attr_accessor :cdcmd       # CDCMD
  attr_accessor :interval    # Integer (seconds)
  attr_accessor :history     # CappedArray[ CDCMD::Result ]
  attr_accessor :thread      # Thread
end

class Stimulant
  include OrganicStructure
  attr_accessor :id          # "identifier"
  attr_accessor :direction   # %i(inbound outbound)
  attr_accessor :instruction # %i(eject pause restart)
  attr_accessor :result      # CDCMD::Result
end


class Controller
  attr_reader :tuplespace
  attr_reader :historylimit # Integer
  attr_reader :pool         # String
  attr_reader :job          # Hash { 'id' => Job }
  attr_reader :bindip
  attr_reader :port

  def initialize pool, historylimit, log, bindip, port
    @tuplespace   = Rinda::TupleSpace.new 15 # affects expire
    @historylimit = historylimit
    @pool         = B::Path.new(pool).prepare_dir
    @job          = { }
    @log          = log
    @bindip       = bindip
    @port         = port
    uri           = "druby://#{@bindip}:#{@port}"
    DRb.start_service uri, self
    log.i %Q`#{self.class} is ready at "#{DRb.uri}"`
    start_observer
  end

  def load filename
    for id,hash in YAML.load_file filename
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

  def add id:'', d:, c:, o:'', i:nil
    @job[id] = Job.new(
      is_active: true,
      interval:  i,
      history:   CappedArray.new(@historylimit, :unlink),
      cdcmd:     CDCMD.new(
        directory: d,
        command:   c,
        option:    o,
      ),
    )
    start_thread id
  end

  def execute id, duration:3600
    result = @job[id].cdcmd.run prefix:id, pool:@pool do |pid|
      @log.i "START #{id} (pid:#{pid})"
    end
    time_spent = B::TimeLength.sec_to_hms result.time_spent
    @log.i "END   #{id} (pid:#{result.pid}) #{time_spent}"
    @job[id].history.push result
    tuple = Stimulant.new(
      id:        id,
      direction: :outbound,
      result:    result,
    ).to_hash
    @tuplespace.write tuple, duration
  end

  def send_eject identifier
    @tuplespace.write Stimulant.new(
      id:          identifier,
      direction:   :inbound,
      instruction: :eject,
    ).to_hash
  end

  def send_pause identifier
    @tuplespace.write Stimulant.new(
      id:          identifier,
      direction:   :inbound,
      instruction: :pause,
    ).to_hash
  end

  def send_restart identifier
    @tuplespace.write Stimulant.new(
      id:          identifier,
      direction:   :inbound,
      instruction: :restart,
    ).to_hash
  end

  def send_run identifier
    @tuplespace.write Stimulant.new(
      id:          identifier,
      direction:   :inbound,
      instruction: :hand_execution,
    ).to_hash
  end

  def r
    @job.keys.select do |id|
      @job[id].cdcmd.is_running?
    end
  end

  def timedriven
    for id,job in @job
      unless job.interval.nil?
        send_run id
        sleep 1
      end
    end
  end

  def stop_thread id
    send_eject id
    @job[id]&.thread&.join
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

  # no data -> nil
  # seconds -> Float
  def seconds_since_last id
    t = @job[id].history&.last&.time_end
    if t
      Time.now - t
    end
  end

  def seconds_until_next id
    t = seconds_since_last id
    if t and @job[id].interval
      @job[id].interval - t
    end
  end

  def tuples
    @tuplespace.read_all Stimulant.new.to_hash
  end

  def history
    @job.values.map(&:history).flatten.sort_by(&:time_end)
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

  def start_observer
    ob = Thread.new do
      observer = @tuplespace.notify nil, Stimulant.new.to_hash
      for event,tuple in observer
        @log.d "#{event} #{tuple.inspect}"
      end
    end
    ob.name = 'TuplespaceObserver'
  end

  def start_thread identifier
    t = Thread.new identifier do |id|
      patt = Stimulant.new(id:id, direction: :inbound).to_hash
      loop do
        tuple = if @job[id].is_active
                  begin
                    @tuplespace.take patt, @job[id].interval
                  rescue Rinda::RequestExpiredError
                    patt.merge(
                      'instruction' => :cyclic_execution
                    )
                  end
                else
                  @tuplespace.take patt.merge(
                    'instruction' => /eject|restart|pause/
                  )
                end
        case tuple['instruction']
        when :eject
          @job.delete id
          break
        when :pause
          @job[id].is_active = false
        when :restart
          @job[id].is_active = true
        else
          execute id
        end
      end
      @log.i %Q`Thread terminated "#{identifier}"`
    end
    t.name = identifier
    @job[identifier].thread = t
    @log.i %Q`Thread started "#{identifier}"`
    t
  end
end

