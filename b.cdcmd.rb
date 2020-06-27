
require_relative 'b.tmpf.rb'
require_relative 'b.structure.rb'
require_relative 'b.path.rb'

module B
end

#
# chdir && run command
#
class B::CDCMD
  include B::Structure

  attr_reader :tag       # String
  attr_reader :capture   # B::Path

  attr_reader :directory # B::Path
  attr_reader :command   # B::Path
  attr_reader :option    # String

  attr_reader :out
  attr_reader :err

  #
  # Setter
  #

  def tag= o
    @tag = o.to_s
  end

  def capture= o
    @capture = B::Path.new(o).expand!
    @capture.prepare_dir!
  end

  def directory= o
    @directory = B::Path.new(o).expand!
    unless @directory.directory?
      raise Error, "not a directory -> #{o.inspect}"
    end
  end

  def command= o
    @command = B::Path.new(o).expand!(@directory || '.')
    unless @command.executable_file?
      raise Error, "not a executable file -> #{o.inspect}"
    end
  end

  def option= o
    @option = o&.to_s&.strip
  end

  #
  # Constructor
  #

  def after_initialize
    @out = B::TMPF.new dir:@capture, name:@tag, suffix:'out', age:10
    @err = B::TMPF.new dir:@capture, name:@tag, suffix:'err', age:100
  end

  #
  # Status
  #

  def is_running?
    @start != nil
  end

  def start_time_of_current_run
    @start.clone
  end

  #
  # Main Functions
  #

  def run &block
    result = Result.new tag:@tag
    t = B::TMPF::make_time
    r = B::TMPF::make_random 4
    @out.open time:t, random:r do |fo|
      @err.open time:t, random:r do |fe|
        @start = Time.now
        pid = spawn(
          "'#{@command.to_s}' #{@option}",
          pgroup: true,
          chdir:  @directory.to_s,
          out:    fo.fileno,
          err:    fe.fileno,
        )
        block&.call pid, r
        Process.waitpid pid
        result.path_out = fo.path
        result.path_err = fe.path
        result.pid      = pid
      end
    end
    result.status     = $?.exitstatus
    result.time_start = @start
    result.time_end   = Time.now
    result.time_spent = result.time_end - @start
    @start = nil
    return result
  end

  #
  # Misc
  #

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

  #
  # Ancillary Classes
  #

  class Result
    include B::Structure
    attr_accessor :tag
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

