
require 'securerandom'
require_relative 'b.path.rb'

module B
end

class B::TMPF

  DELIMITER = '.'

  def self.make_time t=Time.now
    "%02d%02d%s%02d%02d" % [
      t.month,
      t.day,
      ["su", "mo", "tu", "we", "th", "fr", "sa"][t.wday],
      t.hour,
      t.min,
    ]
  end

  def self.make_random
    SecureRandom.alphanumeric 5
  end

  #
  # instance methods
  #

  attr_reader :history # [ "fullpath" ]
  attr_reader :age
  attr_reader :directory
  attr_reader :prefix
  attr_reader :basename
  attr_reader :suffix

  def initialize(
    age:    20,
    dir:    nil,
    prefix: nil,
    name:   ,
    suffix: nil
  )
    @directory = B::Path.new(dir).expand!
    @directory.prepare_dir!
    @prefix    = prefix
    @basename  = name
    @suffix    = suffix
    @age       = age
    @WILDCARD  = self.make_path(
      time:'*',
      random:'*',
    ).gsub(/\.?\*\.?/, '*').sub('**', '*').freeze
    self.scan
  end

  def open(
    time:   self.class.make_time,
    random: self.class.make_random,
    &block
  )
    return nil if block.nil?
    path = self.make_path time:time, random:random
    size = nil
    body = nil
    File.open(path, "w+b") do |handle|
      block.call handle
      size = handle.size
      body = handle.pread(size, 0) unless size.zero?
    end

    del = false
    if size == 0
      del = true
    else
      unless @history.empty?
        lasttime = File.open(@history.last, "rb").read
        if body == lasttime
          del = true
        end
      end
    end
    del ? File.unlink(path) : self.push(path)
    return !del
  end

  def make_path(
    time:   self.class.make_time,
    random: self.class.make_random
  )
    @directory.to_s(tail:true) + [
      @prefix,
      @basename,
      time,
      random,
      @suffix,
    ].compact.join(DELIMITER)
  end

  #
  # private methods
  #

  private

  def scan
    @history = Dir.glob(@WILDCARD).sort
    overflow = @history.size - @age
    if overflow > 0
      File.unlink(*@history.shift(overflow))
    end
  end

  def push newpath
    @history.push newpath.to_s
    if @history.size > @age
      File.unlink @history.shift
    end
  end
end

