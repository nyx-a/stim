
module Trapper
  def self.procedure= p
    @procedure = p
  end

  def self.sleep
    @sleeper = Thread.new { Kernel.sleep }
    @sleeper.join
  end

  def self.wake
    begin
      @sleeper.run
    rescue ThreadError
      # sleeper thread is already dead.
    end
  end

  @command = -> sno do
    @procedure&.call "#{Signal.signame(sno)}(#{sno})"
    self.wake
  end

  Signal.trap :INT, @command
  Signal.trap :TERM, @command
end

