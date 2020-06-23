
module Trapper
  Signal.trap(:INT ) { self.wake }
  Signal.trap(:TERM) { self.wake }

  def self.sleep
    @sleeper = Thread.new do
      Kernel.sleep
      yield if block_given?
    end
    @sleeper.join
    nil
  end

  def self.wake
    begin
      @sleeper&.run&.join
    rescue ThreadError
      # do nothing.
      # sleeper thread is already dead.
    end
  end
end

