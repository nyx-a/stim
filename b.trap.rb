
require 'singleton'

module B
  # for namespace
end

class B::Trap
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

  def self.add *parameter, &block
    return nil if block.nil?
    return nil if @@interrupted
    t = Thread.new(*parameter) do |*p|
      block.call(*p)
    end
    @@group.add t
    return t
  end

  def self.sleep sec=nil
    t = Thread.new do
      if sec.nil?
        Kernel.sleep
      else
        Kernel.sleep sec
      end
    end
    @@group.add t
    t.join
    return @@interrupted
  end

  def self.interrupted?
    @@interrupted
  end
end
