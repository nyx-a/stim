
require 'singleton'

class Trap
  include Singleton

  @@interrupted = false
  @@group = ThreadGroup.new

  @@proc = Proc.new do
    puts "SIGINT trapped (thread:#{@@group.list.size})"
    @@interrupted = true
    for t in @@group.list
      begin
        t.run
      rescue ThreadError
        # killed (normally dead) thread
      end
    end
  end

  @@last = Signal.trap('INT', @@proc)

  def self.start &block
    return nil if block.nil?
    t = Thread.new { block.call }
    @@group.add t
    t.join
    return @@interrupted
  end

  def self.interrupted
    @@interrupted
  end
end
