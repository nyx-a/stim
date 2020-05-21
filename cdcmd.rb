
require 'tempfile'
require_relative 'os.rb'
require_relative 'path.rb'

# chdir && run command
class CDCMD
  include OrganicStructure

  attr_reader :directory # String
  attr_reader :command   # String
  attr_reader :option    # String

  def directory= o
    p = B::Path.new(o).expand
    if p.directory?
      @directory = p.to_s
    else
      raise Error, "not a directory `#{o.inspect}`"
    end
  end

  def command= o
    p = B::Path.new(o).expand(@directory || '.')
    if p.executable_file?
      @command = p.to_s
    else
      raise Error, "not a executable file `#{o.to_s}`"
    end
  end

  def option= o
    @option = o&.to_s&.strip
  end

  def is_running?
    @start != nil
  end

  def start_time_of_current_run
    @start.clone
  end

  def run prefix:'', pool:'.', &block
    prefix = "#{prefix}." unless prefix.empty?
    out = Tempfile.create [prefix, '.out'], pool
    err = Tempfile.create [prefix, '.err'], pool
    @start = Time.now
    pid = spawn(
      "'#{@command}' #{@option}",
      pgroup: true,
      chdir:  @directory,
      out:    out.fileno,
      err:    err.fileno,
    )
    block&.call pid
    Process.waitpid pid
    te = Time.now
    ts = @start
    @start = nil
    out.close
    err.close
    Result.new(
      pid:        pid,
      status:     $?.exitstatus,
      path_out:   out.path,
      path_err:   err.path,
      time_start: ts,
      time_end:   te,
      time_spent: te - ts,
    )
  end

  def signature
    [directory, command, option].join
  end
  protected :signature

  def === other
    if other.is_a? self.class
      self.signature == other.signature
    end
  end

  def hash
    self.signature.hash
  end

  class Result
    include OrganicStructure
    attr_accessor :pid
    attr_accessor :status
    attr_accessor :path_out
    attr_accessor :path_err
    attr_accessor :time_start
    attr_accessor :time_end
    attr_accessor :time_spent
    def unlink
      File.unlink @path_out, @path_err
    end
  end

  class Error < StandardError
  end
end

