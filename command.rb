
# - Command#run returns a Result
# - Result has a pair of Outputs (stdout & stderr)
# - History has many Results

require 'yaml'
require_relative 'b.structure.rb'
require_relative 'b.enum.rb'
require_relative 'b.path.rb'


#
#* Why the output file does not exist
#

Absent = B::Enum.new :expire, :dup, :empty, :abduction

def Absent.funnel other, nilable:
  if other.nil?
    if nilable
      nil
    else
      raise 'nil cannot be passed through'
    end
  else
    other.is_a?(self) ? other : self.new(other.to_sym)
  end
end

#
#* A output file
#

class Output < B::Structure
  attr_reader :path   # B::Path
  attr_reader :size   # Integer
  attr_reader :absent # Absent or nil

  def absent?
    not @absent.nil?
  end

  def present?
    @absent.nil?
  end

  def initialize path:, size:, absent:nil
    @path   = B::Path.new path, confirm:nil
    @size   = size
    @absent = Absent.funnel absent, nilable:true
    if present?
      if @size.zero?
        unlink :empty
      elsif not @path.exist?
        @absent = Absent.new :abduction
      end
    end
  end

  def same_as o
    if present? and o.present?
      if @size!=0 and @size==o.size
        if @path.exist? and o.path.exist?
          @path.open('rb').read == o.path.open('rb').read
        end
      end
    end
  end

  def unlink r
    if present?
      @absent = Absent.funnel r, nilable:false
      @path.unlink
    end
  end

  def self.funnel other
    case other
    when self
      other
    when Hash
      self.new(**other.transform_keys(&:to_sym))
    else
      raise TypeError, "can't change #{other} to #{self}"
    end
  end
end

#
#* Command run result
#

class Result < B::Structure
  attr_reader :pid    # Integer
  attr_reader :status # Integer
  attr_reader :start  # Time
  attr_reader :end    # Time
  attr_reader :stdout # Output
  attr_reader :stderr # Output

  def pid= o
    raise TypeError unless o.is_a? Integer
    @pid = o
  end

  def status= o
    raise TypeError unless o.is_a? Integer
    @status = o
  end

  def start= o
    raise TypeError unless o.is_a? Time
    @start = o
  end

  def end= o
    raise TypeError unless o.is_a? Time
    @end = o
  end

  def stdout= o
    @stdout = Output.funnel o
  end

  def stderr= o
    @stderr = Output.funnel o
  end

  def time_spent
    if @end and @start
      @end - @start
    end
  end

  def unlink reason
    @stdout.unlink reason
    @stderr.unlink reason
  end

  def same_as o
    @stdout.same_as o.stdout and @stderr.same_as o.stderr
  end
end

#
#* Serializable Capped Array ( for Result )
#

class History
  def initialize limit:30, load:nil
    @mutex = Mutex.new
    @limit = limit
    @array = [ ]
    load_file(load) if load
  end

  def push nr
    if !@array.empty? and nr.same_as @array.last
      nr.unlink :dup
    end
    @mutex.synchronize do
      @array.push nr
      while @array.size > @limit
        @array.shift.unlink :expire
      end
    end
    return self
  end

  # to built-in basic types
  def to_b
    @mutex.synchronize do
      @array.map do |i|
        B::Structure.to_h i, k:'to_s', v:->{
          case _1
          when B::Enum then _1.value
          when B::Path then _1.to_s
          else _1
          end
        }
      end
    end
  end

  def save_file path
    open(path, 'w+'){ _1.write YAML::dump to_b }
  end

  def load_file path
    @mutex.synchronize do
      @array.replace self.class.load_file path
    end
  end

  def self.load_file path
    YAML::load_file(path).map{ Result.new(**_1) }
  end
end

#
#* chdir and run command
#

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

  def self.oname dir, prefix, time, suffix
    B::Path.new(dir, confirm:nil).tail + [
      prefix,
      timestamp(time),
      suffix,
    ].flatten.reject(&:empty?).join('.')
  end

  def initialize c:, d:nil, o:nil
    self.cd      = d # 1 this one has to come first
    self.command = c # 2 second
    self.option  = o # ? anyway
  end

  def cd= o
    @cd = o ? B::Path.new(o, confirm:'directory') : '.'
  end

  def command= o
    @command = B::Path.new(
      o, base:@cd, confirm:['file', 'executable']
    )
  end

  def option= o
    @option = o&.to_s&.strip || ''
  end

  def cmdopt
    @option.empty? ? @command : "'#{@command}' #{@option}"
  end

  def run capdir, prefix='', &block
    now = Time.now
    oh = self.class.oname(capdir, prefix, now, 'out').open 'w+b'
    eh = self.class.oname(capdir, prefix, now, 'err').open 'w+b'

    r = Result.new start:now
    r.pid = spawn(
      self.cmdopt,
      pgroup: true,
      chdir:  @cd,
      out:    oh.fileno,
      err:    eh.fileno,
    )
    block&.call r # At this point, r.pid and r.start are available.
    Process.waitpid r.pid
    r.end    = Time.now
    r.status = $?.exitstatus
    r.stdout = Output.new path:oh.path, size:oh.size
    r.stderr = Output.new path:eh.path, size:eh.size
    oh.close
    eh.close
    return r
  end
end

