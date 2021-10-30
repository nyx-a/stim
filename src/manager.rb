
require 'colorize'
require_relative 'command.rb'
require_relative 'recipe.rb'
require_relative 'socket-helper.rb'
require_relative 'b.path.rb'
require_relative 'b.log.rb'
require_relative 'b.text.rb'

class Manager

  Description = {
    'files'     => 'show recipe files',
    'jobs'      => 'show jobs',
    'tree'      => 'show tree',
    'execute'   => 'manually execute the specified job(s)',
    'pause'     => 'pauses the specified job(s)',
    'resume'    => 'resume the specified job(s)',
    'terminate' => 'terminate stim',
    'help'      => 'show help',
  }.freeze

  def initialize bind:, port:, capture:, log:, timeout:3600
    @alive      = true
    @recipe     = [ ]
    @timeout    = timeout
    @log        = log
    @capture    = B::Path.new capture, confirm:'directory'
    @bind       = bind
    @port       = port
    Job.capture = @capture
    Job.log     = @log
  end

  def add_recipe *path
    for p in path.flatten
      @log.d "#{__callee__}(#{p.inspect})"
      @recipe.push Recipe.new(p).load!
    end
  end

  # <- Array[ Recipe ]
  def recipe_grep name='.'
    @recipe.select{ |r| r.name === name }
  end

  # <- Array[ Job ]
  def job_grep name='.'
    recipe_grep(name)
      .map{ |r| r.job.select{ |n| n.name === name } }
      .flatten
  end

  def terminate
    @alive = false
    @recipe.each &:unload!
    release
  end

  def stand_by
    @sleeper = Thread.new{ Kernel.sleep }
    @sleeper.join
  end

  def release
    @sleeper.run
  end

  def server_start
    Thread.start do
      tcpserver = TCPServer.new @bind, @port
      loop do
        socket = tcpserver.accept
        socket.extend SocketHelper
        @log.i "#{socket.opponent} is accepted"

        socket.send_object(
          verb: Description.keys,
          noun: job_grep.map{ _1.name.to_s },
        )
        repl socket

        @log.i "#{socket.opponent} is gone"
        socket.close
      end
    end
  end

  def repl socket
    while @alive and m=socket.r
      begin
        cmd,*arg = m.split
        nm = Name.new arg
        socket.w case cmd
                 when 'files'
                   B.table recipe_grep(nm).map{
                     [
                       _1.name.to_s.colorize(:yellow),
                       _1.time.to_s,
                       recipe_status(_1),
                     ]
                   }
                 when 'jobs'
                   B.table job_grep(nm).map{
                     [
                       _1.name,
                       _1.state,
                       _1.remaining_time
                     ]
                   }
                 when 'tree'
                   @recipe.map {
                     _1.name.to_s + "\n" + B.tree(_1.node)
                   }.join("\n")
                 when 'execute'
                   execute nm
                 when 'pause'
                   pause nm
                 when 'resume'
                   resume nm
                 when 'terminate'
                   terminate
                   "The server has been terminated.\nPlease disconnect."
                 when 'help', '?'
                   B.table Description.to_a
                 else
                   "no such command #{cmd}"
                 end
      rescue => err
        @log.e err.full_message
        socket.w 'An error occurred. Please check the server logs.'
      end
    end
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def execute name
    job_grep(name).map{ |j|
      Thread.new { j.execute }
      j.name
    }.map{
      "execute #{_1}"
    }.join("\n")
  end

  def pause name
    job_grep(name).map{ |j|
      Thread.new { j.pause }
      j.name
    }.map{
      "pause #{_1}"
    }.join("\n")
  end

  def resume name
    job_grep(name).map{ |j|
      Thread.new { j.resume }
      j.name
    }.map{
      "resume #{_1}"
    }.join("\n")
  end

  def recipe_status r
    if r.missing?
      'Missing'.colorize(:blue)
    elsif r.modified?
      'Modified'.colorize(:red)
    else
      'Up to date'.colorize(:cyan)
    end
  end

end

