
require 'yaml'
require_relative 'b/trap.rb'
require_relative 'b/log.rb'
require_relative 'b/datedfile.rb'
require_relative 'b/timeamount.rb'
require_relative 'b/organ.rb'
require_relative 'stim-misc.rb'

class Stimming
  def getnode name
    if name.is_a? Array
      name.map{ |y| getnode y }
    else
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
        waiting.push opt_t.map(&:name) unless opt_t.nil?
        waiting.uniq!
        parent = getnode waiting.flatten.uniq

        if !parent.empty? and !interval.nil?
          raise TriggerDuplicated, name
        end

        newnode = Node.new(
          name:      name,
          directory: dir,
          command:   field['c'],
          options:   field['o'],
          waiting:   waiting,
          parent:    parent,
          interval:  interval,
          log:       @log,
          capture:   @capture,
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
    fullstr = if options.nil? or options.empty?
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
      fullstr,
      pgroup: true,
      chdir:  @directory,
      out:    fo.openfile.fileno,
      err:    fe.openfile.fileno,
    )
    @log.i [
      "START (#{@name})",
      events,
      "pid:#{@pid}"
    ].compact.join(' ')

    Process.waitpid @pid
    @end_time = Time.now
    fo.closefile
    fe.closefile

    @log.i [
      "END   (#{@name})",
      events,
      "pid:#{@pid}",
      ($?.exitstatus==0 ? nil : "ExitStatus:#{$?.exitstatus}"),
      (B::TimeAmount.second_to_string(@end_time - @start_time)),
    ].compact.join(' ')
    @pid = nil
    @start_time = nil

    for d in @child
      d.push fo
    end
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
    [
      "(#{@name})",
      "  directory: #{@directory.inspect}",
      "  command:   #{@command.inspect}",
      "  options:   #{@options.inspect}",
      "  interval:  #{@interval.inspect}",
      "  waiting:   #{@waiting.map{|x|x.join('|')}.inspect}",
      "  parent:    #{@parent.map(&:name)}",
      "  child:     #{@child.map(&:name)}",
    ].join "\n"
  end
end
