
require 'logger'

module B
  # for namespace
end

class B::Log
  def initialize d, age:3, size:1_000_000, f:'%F %T.%1N', s:' | '
    @logger     = Logger.new(d, age, size)
    @format     = f
    @separator  = s
    @padding    = ' ' * Time.now.strftime(@format).length
  end

  def d message
    @logger << make('d', Time.now, message)
  end
  def i message
    @logger << make('i', Time.now, message)
  end
  def w message
    @logger << make('w', Time.now, message)
  end
  def e message
    @logger << make('e', Time.now, message)
  end
  def f message
    @logger << make('f', Time.now, message)
  end

  def blank
    @logger << "- #{@padding}#{@separator}\n"
  end

  def gap
    @logger << "\n"
  end

  def close
    @logger.close
  end

  private

  def make severity, time, message
    tm = time.strftime @format
    h1 = [severity.upcase,   tm      ].join(' ')
    h2 = [severity.downcase, @padding].join(' ')
    [
      h1,
      @separator,
      message.gsub("\n", "\n#{h2}#{@separator}"),
      "\n"
    ].join
  end
end
