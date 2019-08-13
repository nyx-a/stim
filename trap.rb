
require 'singleton'

module B
  # for namespace
end

class B::Trap
  include Singleton

  @@interrupted = false
  @@sleepers = ThreadGroup.new

  @@proc = Proc.new do
    puts "Signal trapped (#{@@sleepers.list.size} threads)"
    @@interrupted = true
    for t in @@sleepers.list
      begin
        t.run
      rescue ThreadError
        # killed (normally dead) thread
      end
    end
  end

  @@int  = Signal.trap 'INT',  @@proc
  @@term = Signal.trap 'TERM', @@proc

  def self.add *parameter, &block
    return nil if block.nil?
    return nil if @@interrupted
    t = Thread.new(*parameter) do |*p|
      block.call(*p)
    end
    @@sleepers.add t
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
    @@sleepers.add t
    t.join
    return @@interrupted
  end

  def self.join
    for t in @@sleepers.list
      t.join
    end
  end

  def self.hand_interrupt
    @@proc.call
  end

  def self.interrupted?
    @@interrupted
  end
end

