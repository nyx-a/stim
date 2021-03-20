
require 'logger'

module B
  # for namespace
end

class B::Log
  def initialize(
    file,
    age:       3,
    size:      1_000_000,
    format:    '%F %T.%1N',
    separator: ' | ',
    levels:    %w(debug information warning error fatal)
  )
    @logger    = Logger.new file, age, size
    @format    = format
    @separator = separator
    @padding   = ' ' * Time.now.strftime(@format).length
    setlevels! levels
  end

  def levels
    @levels
  end

  def setlevels! *ary
    if @levels
      self.class.undef_method(*@levels.map(&:chr))
    end
    @levels = ary.flatten.map(&:to_s).map(&:downcase)
    @levels.each &:freeze
    @levels.freeze
    @active = { }
    for letter in @levels.map(&:chr).map(&:to_sym)
      self.class.alias_method letter, :x
      @active[letter] = true
    end
  end

  def loglevel= lvl
    lvl = lvl.to_s.downcase
    idx = @levels.index lvl
    if idx != nil
      @levels[...idx].each{ @active[_1.chr.to_sym] = false }
      @levels[ idx..].each{ @active[_1.chr.to_sym] = true  }
      return lvl
    end
  end

  # @active[:x] cannot be true
  def x *object, method:'inspect'
    if @active[__callee__]
      @logger << make(
        __callee__,
        Time.now,
        object.map{
          String===_1 ? _1 : _1.public_send(method)
        }.join(' ')
      )
    end
    object.one? ? object.first : object
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

  def make letter, time, message
    tm = time.strftime @format
    h1 = [letter.upcase,   tm      ].join ' '
    h2 = [letter.downcase, @padding].join ' '
    [
      h1,
      @separator,
      message.gsub("\n", "\n#{h2}#{@separator}"),
      "\n"
    ].join
  end
end

