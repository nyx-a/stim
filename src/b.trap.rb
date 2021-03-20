
module B
  def self.trap
    raise unless block_given?
    sleeper = Thread.new do
      Kernel.sleep
      yield
    end
    Signal.trap(:INT ){ sleeper.run }
    Signal.trap(:TERM){ sleeper.run }
  end
end

