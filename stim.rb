#! /usr/bin/env ruby

require 'fileutils'
require_relative 'b.rb'
require_relative 'b.trap.rb'
require_relative 'b.option.rb'
require_relative 'b.log.rb'
require_relative 'b.numfile.rb'
require_relative 'b.timeamount.rb'

#-
class Node
  attr_accessor :name
  attr_accessor :stimulant
  attr_accessor :basedir
  attr_accessor :command # and its parameters
  attr_accessor :log
  attr_accessor :pool
  attr_accessor :limit
  attr_accessor :nextnode

  def start
    Thread.new do
      until B::Trap.interrupted?
        self.execute
        @stimulant.sleep
      end
    end
  end

  def execute
    path = File.join(@pool, @name)
    fo = B::NumFile.new(path + '.out', limit:@limit)
    fe = B::NumFile.new(path + '.err', limit:@limit)
    fo.move!
    fe.move!

    tstt = Time.now
    pid = spawn(
      File.join('.', @command),
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
    lm = es==0 ? @log.method(:i) : @log.method(:e)
    info = [
      "pid:#{$?.pid}",
      "(#{es})",
      ", #{B::TimeAmount.second_to_string(tend - tstt)}",
    ].join(' ')
    lm.call "END   [#{@name}] #{info}"

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

  def command_fullpath
    File.join @basedir, @command.split(' ', 2).first
  end

  def inspect
    [
      "<#{@name}>",
      '  Stimulant : ' + @stimulant.inspect,
      '  Directory : ' + @basedir,
      '  Command   : ' + @command,
    ].join("\n")
  end
end


#-
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

  def readconfig filename
    unless File.exist? filename
      raise SlightError,
        "File not found => '#{filename}'"
    end

    ncnt = 0
    cd = File.expand_path File.dirname $0
    open filename do |fh|
      while line=fh.gets
        if B::peel!(line).empty?
          next
        elsif line[-1] == ':'
          line.chop!
          line = File.expand_path line
          unless File.exist? line
            raise SlightError,
              "Directory doesn't exist => '#{line}'"
          end
          unless File.directory? line
            raise SlightError,
              "Must be directory => '#{line}'"
          end
          cd = line
        else
          part = line.split(/(?=\t)\s+/)
          if part.size != 3
            raise SlightError,
              "Must be 3 items => #{part.inspect}"
          end

          trigger = B::TimeAmount.new(part[0], f:0.1)
          trigger = part[0] if trigger.empty?

          node = Node.new
          node.basedir    = cd
          node.stimulant  = trigger
          node.name       = part[1]
          node.command    = part[2]
          node.log        = @log
          node.pool       = @pool
          node.limit      = @limit

          unless File.exist? node.command_fullpath
            raise SlightError,
              "Command doesn't exist => '#{node.command_fullpath}'"
          end

          if @list_all.has_key? node.name
            raise SlightError,
              "Node name duplicated => '#{node.name}'"
          else
            @list_all[node.name] = node
          end

          case trigger
          when B::TimeAmount
            @list_time[node.name] = node
          when String
            @list_event[node.name] = node
          end
          ncnt += 1
        end
      end
    end
    return ncnt
  end

  def startall
    for node in @list_event.values
      backward = @list_all[node.stimulant]
      if backward.nil?
        raise SlightError,
          "Unmatched name => '#{node.stimulant}'"
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

  def joinall
    for t in @tgrp.list
      t.join
    end
  end

  def empty?
    @list_all.empty?
  end

  def inspect
    @list_all.values.map(&:inspect).join("\n")
  end

  class SlightError < StandardError
  end
end


#-
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


#- options
begin
  opt = B::Option.new(
    'daemon'          => TrueClass,
    'test'            => TrueClass,
    'pool-directory'  => String,
    'Pool-age'        => Integer,
    'log-directory'   => String,
    'Log-age'         => Integer,
    'Log-size'        => Integer,
  )

  opt.underlay(
    'daemon'          => true,
    'pool-directory'  => './pool',
    'Pool-age'        => 100,
    'log-directory'   => './log',
    'Log-age'         => 5,
    'Log-size'        => 1_000_000,
  )

  if opt['test']
    opt['daemon'] = false
  end

  opt['pool-directory'] = check_dir opt['pool-directory']

rescue OptionParser::ParseError => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

#- log
unless opt['daemon']
  opt['log-directory'] = nil
  output = STDOUT
else
  opt['log-directory'] = check_dir opt['log-directory']
  output = File.join opt['log-directory'], "log.#{nametrunk $0}.log"
end
log = B::Log.new(
  output,
  f:    '%m-%d %T',
  age:  opt['Log-age'],
  size: opt['Log-size']
)

#-
begin
  if opt['daemon']
    Process.daemon true
    log.i "Process #{$0} started as daemon. PID=#{$$}"
    log.blank
    pidfile = "pid.#{nametrunk $0}.pid"
    if File.exist? pidfile
      raise Stimming::SlightError,
        "#{pidfile} already exists."
    else
      File.write pidfile, $$
    end
  end

  log.i("Options:\n" + opt.inspect)
  log.blank

  stim = Stimming.new(
    log,
    opt['pool-directory'],
    opt['Pool-age']
  )

  unless opt.excess.empty?
    for f in opt.excess
      log.i "Reading configure file: '#{f}'"
      c = stim.readconfig f
      log.i " -> #{c} node#{c>1 ? 's' : ''}."
    end
    log.blank
  end

  unless stim.empty?
    log.i stim.inspect
    log.blank
  end

  if opt['test']
    log.d "Option '--test' is true."
  else
    B::Trap.start do
      sleep
      log.d '( Signal INT received. )'
    end
    stim.startall
    stim.joinall
  end

  if opt['daemon']
    File.delete pidfile
  end
rescue Stimming::SlightError => err
  log.e err.message
rescue Exception => err
  log.e [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end

log.i "Process Terminated. PID=#{$$}"
log.gap
