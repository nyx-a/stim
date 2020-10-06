
module B
  # for namespace
end

class B::Path

  def initialize s=nil
    case s
    when NilClass
      @tube = [ ]
    when self.class
      @tube = s.deepclone.tube
    when String
      @tube = [ ]
      self.parse s
    else
      raise "Unknown class `#{s.class}`"
    end
    self
  end

  def parse s
    @tube.replace s.strip.split(%r`#{File::SEPARATOR}+`, -1)
    case @tube.last
    when '.', '..' then @tube.push ''
    when '~'
      if @tube.size == 1
        @tube.push ''
      end
    end
    self
  end

  def clone
    n = self.class.new
    n.tube.replace @tube # shallow copy
    n
  end

  def deepclone
    n = self.class.new
    n.tube.replace Marshal.load Marshal.dump @tube
    n
  end

  def replace o
    unless o.is_a? self.class
      raise "Can't replace with `#{o.class}`"
    end
    @tube.replace o.tube
  end

  def to_s tail:true
    e = (!tail and self.branch?) ? -2 : -1
    File.join @tube[0..e]
  end

  def filename
    @tube.last or ''
  end

  def dirname tail:true
    c = self.clone
    c.filename = ''
    c.to_s tail:tail
  end

  def filename= other
    opath = self.class.new other
    if self.empty?
      self.replace opath
    else
      case
      when opath.empty?
        @tube[-1,1] = ''
      when opath.absolute?
        self.un_dir!
        @tube.concat opath.tube[1..]
      else
        @tube[-1,1] = opath.tube
      end
    end
    self
  end

  def dirname= other
    fname = self.filename
    opath = self.class.new other
    if opath.empty?
      @tube.replace [fname]
    else
      self.replace opath.en_dir!
      @tube[-1,1] = fname
    end
    self
  end

  def dir_a
    a = @tube[0..-2]
    a[0] = File::SEPARATOR if a[0]&.empty?
    a
  end

  def + other
    case other
    when self.class
      # do nothing
    when String
      other = self.class.new other
    else
      raise "Can't append class `#{other.class}`"
    end
    if other.empty?
      self.deepclone
    elsif other.absolute?
      if self.empty?
        other.deepclone
      else
        raise "Can't append absolute path `#{other.to_s}`"
      end
    else
      chomp = @tube.last&.empty? ? @tube[0..-2] : @tube
      n = self.class.new
      n.tube.replace chomp + other.tube
      n.deepclone
    end
  end

  def empty?
    @tube.empty?
  end

  def root?
    @tube == ['','']
  end

  def single?
    @tube.size == 1
  end

  def branch?
    !self.root? and self.is_dir?
  end

  def absolute?
    @tube.first&.empty?
  end

  def relativize!
    @tube.shift if self.absolute?
    self
  end

  def absolutize!
    @tube.unshift '' unless self.absolute?
    self
  end

  def is_dir?
    @tube.last&.empty?
  end

  def en_dir!
    if self.empty?
      @tube.replace ['','']
    elsif !self.is_dir?
      @tube.push ''
    end
    self
  end

  def un_dir!
    if self.root?
      @tube.clear
    elsif self.is_dir?
      @tube.pop
    end
    self
  end

  def en_dir
    self.clone.en_dir!
  end

  def un_dir
    self.clone.un_dir!
  end

  def tail
    self.branch? ? File::SEPARATOR : ''
  end

  def expand_s base='.'
    File.expand_path self.to_s, base.to_s
  end

  def expand base='.'
    self.class.new self.expand_s base
  end

  def expand! base='.'
    self.parse self.expand_s base
  end

  def exist? base='.'
    File.exist? self.expand_s base
  end

  def directory? base='.'
    File.directory? self.expand_s base
  end

  def writable? base='.'
    File.writable? self.expand_s base
  end

  def file? base='.'
    File.file? self.expand_s base
  end

  def executable_file? base='.'
    s = self.expand_s base
    File.file? s and File.executable_real? s
  end

  def mkdir base='.'
    self.expand(base).tube[0..-1].inject do |sum,i|
      sum = File.join sum, i
      Dir.mkdir sum unless Dir.exist? sum
      sum
    end
  end

  def prepare_dir! base='.'
    s = self.expand_s base
    if File.exist? s
      if File.directory? s
        self.en_dir! # <- destructive
        if File.writable? s
          # ok
        else
          raise "Not writable `#{s}`"
        end
      else
        raise "Not a directory `#{s}`"
      end
    else
      self.mkdir base
    end
    s
  end

  def delete base='.'
    File.delete self.expand_s base
  end

  def write string, base='.'
    File.write self.expand_s(base), string
  end

  def inspect
    %Q`#{self.class.name}"#{self.to_s}"`
  end

  #
  # for XDG
  #

  XDG_CONFIG_HOME = self.new(
    ENV['XDG_CONFIG_HOME'] || "#{ENV['HOME']}/.config"
  )
  XDG_CONFIG_DIRS = (
    ENV['XDG_CONFIG_DIRS']&.split(':') || ["/etc/xdg"]
  ).map{ |x| self.new x }

  def find_xdg_config
    mock = self.deepclone.relativize!
    for d in [XDG_CONFIG_HOME] + XDG_CONFIG_DIRS
      full = d + mock
      return full if full.exist?
    end
    return nil
  end

  protected

  def tube
    @tube
  end
end



