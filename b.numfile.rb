
module B
  # for namespace
end

class B::NumFile
  attr_accessor :path
  attr_accessor :filename
  attr_accessor :number
  attr_accessor :limit

  def initialize string, limit:Float::INFINITY
    @path     = nil
    @filename = nil
    @number   = nil
    @limit    = limit
    self.readname string
  end

  def readname string
    if string =~ %r{(.+)/(.*)}
      @path  = $1
      string = $2
    end
    if string.empty?
      raise "filename is not given"
    end
    if string =~ /\A\[(\d+)\]/
      @number   = $1.to_i
      @filename = $'
    else
      @number   = 0
      @filename = string
    end
  end

  def to_s
    [
      (@path.nil? ? '' : @path + '/'),
      (@number.nil? ? '' : '[%03d]' % @number),
      @filename,
    ].join(nil)
  end

  def save contents
    if contents.empty?
      return
    end
    self.move!
    open(self.to_s, 'wb') do |fo|
      fo << contents
    end
  end

  def load
    if self.exists?
      open(self.to_s, 'rb').read
    else
      nil
    end
  end

  def diff contents
    contents = contents.dup
    contents.force_encoding 'BINARY'
    self.load != contents
  end

  def save_if_diff contents
    if self.diff contents
      self.save contents
      if block_given?
        yield self.to_s
      end
      return true
    else
      return false
    end
  end

  def exists?
    File.exists? self.to_s
  end

  def zero?
    File.zero? self.to_s
  end

  def delete!
    File.delete self.to_s
  end

  def move!
    if self.exists?
      if self.zero?
        self.delete!
      else
        if @number >= @limit
          self.delete!
        else
          ahead = self + 1
          if ahead.exists?
            ahead.move!
          end
          File.rename self.to_s, ahead.to_s
        end
      end
    end
  end

  def + offset
    new = self.clone
    new.number += offset
    return new
  end

  def - offset
    self + -offset
  end

  def inspect
    [
      "    path : #{@path.inspect}",
      "filename : #{@filename.inspect}",
      "  number : #{@number.inspect}",
      "   limit : #{@limit.inspect}",
      "    to_s : #{self.to_s.inspect}",
    ].join("\n")
  end
end
