
# Command#run returns a Result
# Result has 2 Outputs
# History has many Results

require 'yaml'
require_relative 'b.structure.rb'
require_relative 'b.enum.rb'
require_relative 'b.path.rb'
require_relative 'b.len.rb'


# Why the output is absent.
Reason = B::Enum.new(
  :expire,
  :dup,
  :empty,
)

class Output < B::Structure
  attr_accessor :path   # String
  attr_accessor :size   # Integer
  attr_reader   :absent # Reason / nil

  def absent= r
    @absent = r.nil? || r.is_a?(Reason) ? r : Reason.new(r)
  end

  def present?
    @absent.nil?
  end

  def initialize(...)
    super(...)
    if self.present? and @size.zero?
      self.unlink :empty
    end
  end

  def same_as o
    if self.present? and o.present?
      if @size.nonzero? and @size==o.size
        if @path.exist? and o.path.exist?
          s =  @path.open('rb').read
          o = o.path.open('rb').read
          s == o
        end
      end
    end
  end

  def unlink reason
    if self.present?
      @path.unlink
      @absent = reason
    end
  end

  def to_hash k:'to_s', v:'itself'
    {
      path:   @path,
      size:   @size,
      absent: @absent&.value,
    }.to_h{ [ _1.public_send(k), _2&.public_send(v) ] }
  end
end


#-
class Result < B::Structure
  attr_accessor :pid    # Integer
  attr_accessor :status # Integer
  attr_accessor :start  # Time
  attr_accessor :end    # Time
  attr_accessor :stdout # Output
  attr_accessor :stderr # Output

  def len
    if @end and @start
      B::Len.atom(@end - @start)
    end
  end

  def unlink reason
    @stdout.unlink reason
    @stderr.unlink reason
  end

  def same_as o
    @stdout.same_as o.stdout and @stderr.same_as o.stderr
  end

  def absent?
    stdout.absent and stderr.absent
  end

  def self.load_hash hash
    hash = hash.clone
    hash['stdout'] = Output.new(**hash['stdout'])
    hash['stderr'] = Output.new(**hash['stderr'])
    Result.new(**hash)
  end
end


#- Serializable Capped Array ( for Result )
class History < Array
  def initialize limit:30, load:nil
    @limit = limit
    self.load(load) if load
  end

  def add newresult
    if newresult.same_as self.last
      newresult.unlink :dup
    end
    self.push newresult
    while self.size > @limit
      self.shift.unlink :expire
    end
    return self
  end

  def save_file path
    path.open('w+') do |fo|
      data = self.map &:to_hash
      fo.write YAML::dump data
    end
    return self
  end

  def self.load_file path
    YAML::load_file(path).map do |h|
      Result.new(**h)
    end
    return self
  end
end


#-
class Command < B::Structure
  attr_reader :cd      # B::Path
  attr_reader :command # B::Path
  attr_reader :option  # String

  def self.timestamp t=Time.now
    "%02d%02d%s%02d%02d%02d" % [
      t.month,
      t.day,
      %w(su mo tu we th fr sa)[t.wday],
      t.hour,
      t.min,
      t.sec,
    ]
  end

  def cd= o
    @cd = B::Path.directory o
  end

  def command= o
    @command = B::Path.new(
      o,
      base:    (@cd or '.'),
      confirm: [:file, :executable],
    )
  end

  def option= o
    @option = o&.to_s&.strip
  end

  def run *prefix, capdir:, &block
    c_d = capdir.tail
    t_s = self.class.timestamp
    n_o = c_d + (prefix.flatten + [t_s, 'out']).join('.')
    n_e = c_d + (prefix.flatten + [t_s, 'err']).join('.')
    h_o = n_o.open 'w+b'
    h_e = n_e.open 'w+b'

    r = Result.new start:Time.now
    r.pid = spawn(
      "'#{@command}' #{@option}",
      pgroup: true,
      chdir:  @cd,
      out:    h_o.fileno,
      err:    h_e.fileno,
    )
    block&.call r # .pid and .start are available
    Process.waitpid r.pid
    r.end    = Time.now
    r.status = $?.exitstatus

    r.stdout = Output.new path:h_o.path, size:h_o.size
    r.stderr = Output.new path:h_e.path, size:h_e.size
    h_o.close
    h_e.close
    return r
  end
end

