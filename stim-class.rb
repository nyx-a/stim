
require 'yaml'
require_relative 'trap.rb'
require_relative 'log.rb'
require_relative 'datedfile.rb'
require_relative 'timeamount.rb'
require_relative 'organ.rb'
require_relative 'stim-misc.rb'

class Stimming
  def getnode aon
    aon.map do |name|
      @list.fetch(name){ |k| raise NoSuchNode, k }
    end
  end

  def initialize logger:, captureDir:
    @list    = { }
    @log     = logger
    @capture = captureDir
  end

  def read_yaml path, base_dir:'.'
    yml = YAML.load_file path
    for dir,entry in yml
      dir = File.expand_path dir.to_s, base_dir
      Stimming.raise_if_invalid_directory dir
      for name,field in entry
        name = name.to_s
        field = field.to_h{ |k,v| [k, v.to_s] }

        field['c'] = Stimming.tidyup_path field['c']
        Stimming.raise_if_invalid_command dir, field['c']

        interval = nil
        if field.key? 't'
          begin
            opt_t = getnode Stimming.tokenize field['t']
          rescue NoSuchNode
            interval = B::TimeAmount.new field['t'], f:0.1
            if interval.empty?
              raise InvalidTrigger, field['t']
            end
          end
        end

        waiting = Stimming.scan_tokens field['o']
        need_replace = !waiting.empty?
        waiting.push opt_t.map(&:name) unless opt_t.nil?
        waiting.uniq!
        parent = getnode waiting.flatten.uniq

        if !parent.empty? and !interval.nil?
          raise TriggerDuplicated, name
        end

        newnode = Node.new(
          name:         name,
          directory:    dir,
          command:      field['c'],
          options:      field['o'] || "",
          waiting:      waiting,
          parent:       parent,
          need_replace: need_replace,
          interval:     interval,
          log:          @log,
          capture:      @capture,
        )
        parent.each{ |p| p.child.append newnode }
        @list[name] = newnode
      end
    end
    @list.size
  end

  def waterfall
    @list.each_value(&__callee__)
    self
  end
  alias :start :waterfall
  alias :pause :waterfall
  alias :stop  :waterfall
  alias :join  :waterfall
  undef :waterfall

  def empty?
    @list.empty?
  end

  def inspect
    @list.values.map(&:inspect).join("\n")
  end
end


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

  def start
    @brake = false
    if !@interval.nil? and !@interval.empty?
      start_t
    elsif !@waiting.empty?
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
      @thread.run
    rescue ThreadError
    end
    @thread.join
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
