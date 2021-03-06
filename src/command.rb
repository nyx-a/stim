
require_relative 'result.rb'

#
#* chdir and run command
#

class Command < B::Structure
  attr_reader :directory # B::Path
  attr_reader :command   # B::Path
  attr_reader :option    # String

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

  def initialize command:, directory:nil, option:nil
    self.directory = directory # it needs to be assigned first
    self.command   = command   # second
    self.option    = option
  end

  def directory= o
    @directory = o ? B::Path.new(o, confirm:'directory') : '.'
  end

  def command= o
    @command = B::Path.new(
      o, base:@directory, confirm:['file', 'executable']
    )
  end

  def option= o
    @option = o&.to_s&.strip || ''
  end

  def cmdopt
    @option.empty? ? @command : "'#{@command}' #{@option}"
  end

  def run capture, prefix='', &block
    now = Time.now
    oh = self.class.oname(capture, prefix, now, 'out').open 'w+b'
    eh = self.class.oname(capture, prefix, now, 'err').open 'w+b'

    r = Result.new start:now
    r.pid = spawn(
      self.cmdopt,
      pgroup: true,
      chdir:  @directory,
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

