
require 'fileutils'
require 'b/text.rb'
require 'b/trap.rb'
require 'b/option.rb'
require 'b/log.rb'
require 'b/numfile.rb'
require 'b/timeamount.rb'
require 'b/backdoor.rb'


class Stimming
  include B::Backdoor

  def initialize logger:, captureDir:, captureLimit:
    @tgrp       = ThreadGroup.new
    @list_all   = { }
    @list_time  = { }
    @list_event = { }
    @log        = logger
    @capture    = captureDir
    @limit      = captureLimit
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
          node.capture    = @capture
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
      previous = @list_all[node.stimulant]
      if previous.nil?
        raise SlightError,
          "Unmatched name => '#{node.stimulant}'"
      else
        previous.nextnode = node
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

  def backdoor_repl telegram:, socket:
    reply = ''
    token = telegram.split
    case token.first
    when 'exit', 'quit'
      socket.close
    when 'terminate'
      B::Trap.hand_interrupt
      socket.close
    end
    return reply
  end

  class SlightError < StandardError
  end
end


class Node
  attr_accessor :name
  attr_accessor :stimulant
  attr_accessor :basedir
  attr_accessor :command # and its parameters
  attr_accessor :log
  attr_accessor :capture
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
    path = File.join(@capture, @name)
    fo = B::NumFile.new(path + '.out', limit:@limit)
    fe = B::NumFile.new(path + '.err', limit:@limit)
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
    cmd = @command.split(' ', 2).first
    if cmd =~ %r`^\s*/`
      cmd
    else
      File.join @basedir, cmd
    end
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
