
require_relative 'organ.rb'
require_relative 'trap.rb'
require_relative 'datedfile.rb'
require_relative 'timeamount.rb'

class Node < B::Organ
  attr_accessor :name
  attr_accessor :directory
  attr_accessor :command
  attr_accessor :options
  attr_accessor :parent
  attr_accessor :child
  attr_accessor :queue
  attr_accessor :waiting
  attr_accessor :interval
  attr_accessor :log
  attr_accessor :capture
  attr_accessor :need_replace
  attr_accessor :nodetype

  attr_reader   :pid
  attr_reader   :start_time
  attr_reader   :end_time

  def initialize **h
    @child     = [ ]
    @thread    = nil
    @queue     = nil
    super(**h)
  end

  def execute table:nil
    options = if table.nil?
                @options
              else
                @options.gsub(Stimming::DoubleBracket) do
                  table[Stimming::tokenize $1].fullpath
                end
              end
    fullcmd = if options.nil? or options.empty?
                @command
              else
                [@command, options].join(' ')
              end
    events  = if table.nil?
                nil
              else
                '<-- ' + table.values.map{ |o|
                  '(' + o.name + ')'
                }.join('+')
              end

    fo = B::DatedFile.new dir:@capture, name:@name, ext:'out'
    fe = B::DatedFile.new dir:@capture, name:@name, ext:'err'
    @start_time = Time.now
    @pid = spawn(
      fullcmd,
      pgroup: true,
      chdir:  @directory,
      out:    fo.openfile.fileno,
      err:    fe.openfile.fileno,
    )
    @log.i [
      "START (#{@name})",
      events,
      "pid=#{@pid}"
    ].compact.join(' ')

    Process.waitpid @pid
    @end_time = Time.now
    time_taken = @end_time - @start_time
    fo.closefile
    fe.closefile

    if $?.exitstatus == 0
      lmethod = @log.method :i
      estatus = nil
    else
      lmethod = @log.method :e
      estatus = "EXITSTATUS=#{$?.exitstatus}"
    end
    lmethod.call [
      "END   (#{@name})",
      events,
      "pid=#{@pid}",
      estatus,
      B::TimeAmount.second_to_string(time_taken),
    ].compact.join(' ')
    @pid = nil
    @start_time = nil

    for d in @child
      d.push fo
    end
    return time_taken
  rescue Exception => err
    @log.f [
      err.message,
      '(' + err.class.name + ')',
      err.backtrace,
    ].join("\n")
  end

  def push dtdf
    @queue.push dtdf
  end

  def start_e
    @thread = Thread.new do
      until B::Trap.interrupted? or @brake
        catch :quit do
          cnvtbl = @waiting.to_h{ |x| [x, nil] }
          until cnvtbl.values.all?
            dtdf = @queue.pop
            if dtdf.nil?
              @brake = true
              throw :quit
            end
            for k,v in cnvtbl
              if k.include? dtdf.name
                if v.nil?
                  cnvtbl[k] = dtdf
                end
              end
            end
          end
          execute table:cnvtbl
        end # :quit
      end
    end
  end

  def start_t
    @thread = Thread.new do
      until B::Trap.interrupted? or @brake
        execute
        @interval.sleep
      end
    end
  end

  def start t=nil
    return if t!=nil and @nodetype!=t
    @brake = false
    #if !@interval.nil? and !@interval.empty?
    case @nodetype
    when :interval
      start_t
    when :event
      if @queue.nil?
        @queue = Thread::Queue.new
      end
      start_e
    end
  end

  def stop
    @brake = true
    @queue.push nil unless @queue.nil?
    begin
      @thread&.run
    rescue ThreadError
    end
    @thread&.join
  end

  def join
    @thread.join
  end

  def pause
  end

  def remaining_time
  end

  def elapsed_time
  end

  def inspect
    base = [
      "(#{@name})",
      "  Directory: #{@directory.inspect}",
      "  Command:   #{@command.inspect}",
      "  Options:   #{@options.inspect}",
    ]
    if !@interval.nil? and !@interval.empty?
      base.concat [
        "  Interval:  #{@interval.inspect}",
      ]
    else
      base.concat [
        "  Waiting:   #{@waiting.map{|x|x.join('|')}.inspect}",
        "  Parent:    #{@parent.map(&:name)}",
        "  Child:     #{@child.map(&:name)}",
      ]
    end
    base.join "\n"
  end
end
