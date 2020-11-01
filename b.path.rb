
module B
  # Reinvention
end

class B::Path < String

  def self.dig p, base:'.'
    new = allocate.replace File.expand_path p, base
    new.split(File::SEPARATOR).inject do |stack,iter|
      stack = File.join stack, iter
      Dir.mkdir stack unless Dir.exist? stack
      stack
    end
    new.raise_unless 'writable'
    return new.tail
  end

  def self.directory p, base:'.', confirm:nil
    new = allocate.replace File.expand_path p, base
    cnd = [confirm].flatten.compact.map(&:to_s) | ['directory']
    new.raise_unless cnd
    return new.tail
  end

  def initialize p, base:'.', confirm:'exist'
    replace File.expand_path p, base
    raise_unless confirm if confirm
  end

  def +(...)
    self.class.allocate.replace super(...)
  end

  def dig base:'.'
    replace self.class.dig self, base:base
  end

  #
  # '/' at the right end
  #

  def tail
    sub %r`#{File::SEPARATOR}*$`, File::SEPARATOR
  end
  def tail!
    replace tail
  end
  def untail
    sub %r`#{File::SEPARATOR}+$`, ''
  end
  def untail!
    replace untail
  end

  #
  # File Test
  #

  def nand *menu
    menu.flatten.reject{ File.public_send "#{_1}?", self }
  end
  def confirm(...)
    nand(...).empty?
  end
  def aint(...)
    not confirm(...)
  end
  def raise_unless(...)
    n = nand(...)
    unless n.empty?
      raise "#{self.class}(#{self}) is not #{n.join(',')}"
    end
  end

end

