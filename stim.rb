#! /usr/bin/env ruby

require_relative 'b.trap.rb'
require_relative 'b.option.rb'
require_relative 'b.log.rb'
require_relative 'b.rb'
require_relative 'b.numfile.rb'
require_relative 'b.duration.rb'


class Node
  attr_accessor :name
  attr_accessor :stimulant
  attr_accessor :basedir
  attr_accessor :command
  attr_accessor :log
  attr_accessor :pool
  attr_accessor :limit
  attr_accessor :nextnode

  def start
    Thread.new do
      until Trap.interrupted
        self.execute
        @stimulant.sleep
      end
    end
  end

  def execute
    path = File.join(@pool, @name)
    fo = NumFile.new(path + '.out', limit:@limit)
    fe = NumFile.new(path + '.err', limit:@limit)
    fo.move!
    fe.move!

    tstt = Time.now
    pid = spawn(
      @command,
      pgroup: true,
      chdir:  @basedir,
      out:    fo.to_s,
      err:    fe.to_s
    )
    @log.i "START [#{@name}] pid:#{pid}"
    Process.waitpid pid
    tend = Time.now
    fo.delete! if fo.zero?
    fe.delete! if fe.zero?

    es = $?.exitstatus
    l = es==0 ? @log.method(:i) : @log.method(:e)
    info = [
      "pid:#{$?.pid}",
      "(#{es})",
      ", #{Duration.second_to_string(tend - tstt)}",
    ].join(' ')
    l.call "END   [#{@name}] #{info}"

    unless @nextnode.nil?
      Thread.new do
        @log.i "      (#{@name}) --> (#{@nextnode.name})"
        @nextnode.execute
      end
    end
  rescue Exception => err
    @log.f [
      err.message,
      '(' + err.class.name + ')',
      err.backtrace,
    ].join("\n")
  end

  def inspect
    [
      "<#{self.class.name}:#{@name.inspect}>",
      '  Stimulant : ' + @stimulant.inspect,
      '  Directory : ' + @basedir,
      '  Command   : ' + @command,
    ].join("\n")
  end
end

#--

class Stimming
  def initialize log, pd, pl
    @tgrp       = ThreadGroup.new
    @list_all   = { }
    @list_time  = { }
    @list_event = { }
    @log        = log
    @pool       = pd
    @limit      = pl
  end

  def read filename
    unless File.exist? filename
      raise "file not found => '#{filename}'"
    end

    cd = File.expand_path File.dirname $0
    open filename do |fh|
      while line=fh.gets
        if peel!(line).empty?
          next
        elsif line[-1] == ':'
          line.chop!
          line = File.expand_path line
          unless File.exist?(line) and File.directory?(line)
            raise "must be directory => '#{line}'"
          end
          cd = line
        else
          part = line.split(/(?=\t)\s+/)#.reject(&:empty?)
          if part.size != 3
            raise "must be consists of 3 parts #{part.inspect}"
          end

          trigger = Duration.new(part[0], f:0.1)
          trigger = part[0] if trigger.empty?

          node = Node.new
          node.basedir    = cd
          node.stimulant  = trigger
          node.name       = part[1]
          node.command    = part[2]
          node.log        = @log
          node.pool       = @pool
          node.limit      = @limit

          if @list_all.has_key? node.name
            raise "node name '#{node.name}' is duplicated " +
              "in file '#{filename}'"
          else
            @list_all[node.name] = node
          end

          case trigger
          when Duration
            @list_time[node.name] = node
          when String
            @list_event[node.name] = node
          end
        end
      end
    end
  end

  def startall
    for node in @list_event.values
      backward = @list_all[node.stimulant]
      if backward.nil?
        raise "unmatched name => '#{node.stimulant}'"
      else
        backward.nextnode = node
      end
    end

    for node in @list_time.values
      t = node.start
      @tgrp.add t unless t.nil?
      sleep 1
    end
  end

  def join
    for t in @tgrp.list
      t.join
    end
  end

  def inspect
    @list_all.values.map(&:inspect).join("\n")
  end
end

#--

def check_dir path
  path = File.expand_path path
  if File.exist? path
    if File.directory? path
      if File.writable? path
        # ok
      else
        raise "not writable => '#{path}'"
      end
    else
      raise "not directory => '#{path}'"
    end
  else
    FileUtils.mkpath path
  end
  return path
end

def nametrunk path
  File.basename(path, '.*')
end

#--

#- option
opt = Option.new(
  'daemonize'       => TrueClass,
  'no-operation'    => TrueClass,
  'pool-directory'  => String,
  'POOL-AGE'        => Integer,
  'log-directory'   => String,
  'LOG-AGE'         => Integer,
  'LOG-SIZE'        => Integer,
)
opt.underlay(
  'daemonize'       => false,
  'no-operation'    => false,
  'pool-directory'  => './pool',
  'POOL-AGE'        => 100,
  'log-directory'   => './log',
  'LOG-AGE'         => 5,
  'LOG-SIZE'        => 1_000_000,
)

if opt['no-operation']
  opt['daemonize'] = false
end

#- log
if not opt['daemonize']
  opt['log-file']      = STDOUT
  opt['log-directory'] = nil
else
  opt['log-directory'] = check_dir opt['log-directory']
  opt['log-file']      = File.join(
    opt['log-directory'],
    "log.#{nametrunk $0}.log"
  )
end
log = Log.new(
  opt['log-file'],
  f:    '%m-%d %T',
  age:  opt['LOG-AGE'],
  size: opt['LOG-SIZE']
)

#-
begin
  if opt['daemonize']
    Process.daemon(true)
    log.i "Process #{$0} started as daemon. PID=#{$$}"
    log.blank
    opt['pid-file'] = "pid.#{nametrunk $0}.pid"
    open(opt['pid-file'], 'w') do |fh|
      fh << $$
    end
  end
  log.i("Options:\n" + opt.inspect)
  log.blank

  opt['pool-directory'] = check_dir opt['pool-directory']
  s = Stimming.new(log, opt['pool-directory'], opt['POOL-AGE'])

  for f in opt.excess
    log.i "Reading configure file: '#{f}'"
    s.read f
  end
  log.blank
  log.i s.inspect
  log.blank

  if opt['no-operation']
    log.d 'break because no-operation option is true'
  else
    s.startall
    s.join
  end

  if opt['daemonize']
    File.delete opt['pid-file']
  end
  log.i 'Process Terminated.'
  log.hardblank

rescue Exception => err
  log.e [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end
