
module B
  # Reinvention
end

class B::Path < String

  def self.dig p, base:'.'
    new = allocate.replace File.expand_path p.to_s, base
    new.split(File::SEPARATOR).inject do |stack,iter|
      stack = File.join stack, iter
      Dir.mkdir stack unless Dir.exist? stack
      stack
    end
    new.raise_unless 'writable'
    return new.tail
  end

  def initialize p, base:'.', confirm:'exist'
    replace File.expand_path p.to_s, base
    raise_unless confirm if confirm
    self.tail! if [confirm].flatten.any? %r/directory/
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
    self.class.allocate.replace(
      sub %r`#{File::SEPARATOR}*$`, File::SEPARATOR
    )
  end

  def tail!
    self.replace tail
  end

  def untail
    self.class.allocate.replace(
      sub %r`#{File::SEPARATOR}+$`, ''
    )
  end

  def untail!
    self.replace untail
  end

  #
  # File Test
  #

  # Converse Non-Implication (other - self)
  def cni *other
    other.flatten.reject{ File.public_send "#{_1}?", self }
  end

  def confirm(...)
    cni(...).empty?
  end

  def aint(...)
    not confirm(...)
  end

  def raise_unless(...)
    n = cni(...)
    unless n.empty?
      raise "#{self.class}(#{self}) is not #{n.join(',')}"
    end
    self
  end
  alias :expect :raise_unless

  #
  # Method Pass through
  #

  def method_missing sym, *args, &block
    if File.respond_to? sym
      File.send sym, self, *args, &block
    else
      super
    end
  end

  def respond_to_missing? sym, include_private
    if File.respond_to? sym
      true
    else
      super
    end
  end

end

