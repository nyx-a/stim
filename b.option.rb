
require 'toml'
require_relative 'b.structure.rb'

module B
end

class B::Option

  def initialize **hsh # { long => description }
    @bare     = [ ]
    @property = [ ] # Property
    @buffer   = { } # Property => "buffer"
    @value    = nil # Property => value
    hsh.each{ register Property.new long:_1, description:_2 }
    if find_l('toml').nil?
      register Property.new(
        long:        'toml',
        description: 'TOML file to underlay',
      )
    end
    if find_l(:help).nil?
      register Property.new(
        long:        'help',
        description: 'Show this help',
        boolean:     true,
      )
    end
  end

  def register *arr
    for p in arr.flatten
      raise "long key cannot be omitted" if p.long.nil?
      raise "long key `#{p.long}` duplicated" if find_l p.long
      raise "short key `#{p.short}` duplicated" if find_s p.short
      @property.push p
    end
  end

  def find_l str
    str = str.to_s
    @property.find{ _1.long == str }
  end
  private :find_l

  def find_s str
    str = str.to_s
    @property.find{ _1.short == str }
  end
  private :find_s

  def plong str
    find_l(str) or raise "invalid long option --#{str}"
  end

  def pshort str
    find_s(str) or raise "invalid short option -#{str}"
  end

  def [] l
    if @value.nil?
      raise "#{self.class} is not available until the make() is called"
    end
    @value[plong l]
  end

  def short **hsh # { long => short }
    hsh.each do
      p = plong _1
      if p.short
        raise "The key #{p.long}(#{p.short}) has already been set"
      end
      p.short = _2
    end
  end

  def boolean *arr # [ long ]
    arr.each{ plong(_1).boolean = true }
  end

  def essential *arr # [ long ]
    arr.each{ plong(_1).essential = true }
  end

  def normalizer **hsh # { long => normalizer }
    hsh.each{ plong(_1).normalizer = _2 }
  end

  def default **hsh # { long => default }
    hsh.each{ plong(_1).default = _2 }
  end

  # parse() raises an exception if there is an unknown key.
  def parse argv
    @bare.clear
    eoo = argv.index '--' # end of options
    if eoo
      tail = argv[eoo+1 ..      ]
      argv = argv[      .. eoo-1]
    end
    re = /^-{1,2}(?=[^-])/
    for first,second in argv.chunk_while{ _1 =~ re and _2 !~ re }
      case first
      when /^--(?i:no)-(?=[^-])/
        # --no-long
        p = plong $~.post_match
        raise "#{p.long} is not boolean" unless p.boolean
        @buffer[p] = false
        @bare.push second if second
      when /^--(?=[^-])/
        # --long
        p = plong $~.post_match
        if p.boolean
          @buffer[p] = true
          @bare.push second if second
        else
          @buffer[p] = second
        end
      when /^-(?=[^-])(?!.*[0-9])/
        # -short
        letters = $~.post_match.chars
        b,o = letters.map{ pshort _1 }.partition &:boolean
        b.each{ @buffer[_1] = true }
        @buffer[o.pop] = second if second && !o.empty?
        o.each{ @buffer[_1] = nil }
      else
        # bare
        @bare.push first
      end
    end
    @bare.concat tail if tail
  end

  # gate() will ignore any unknown keys.
  def gate other
    for k,v in dot_notation(other).slice @property.map(&:long)
      @buffer[plong k] = v
    end
  end

  # If the normalizer returns nil,
  # the original string will be used as is.
  # (Verification only, no conversion.)
  def normalize p
    bd = @buffer[p] || p.default
    return nil if !bd
    begin
      p.normalizer&.call(bd) || bd
    rescue Exception => e
      raise %Q`verification failed --#{p.long} "#{bd}" #{e.message}`
    end
  end
  private :normalize

  def make
    @value = { } # <-- here
    # underlay TOML
    config = normalize plong :toml
    if config
      gate TOML.load_file config
    end
    # overlay command line option
    parse ARGV
    # normalize buffer/default
    for p in @property
      @value[p] = normalize p
    end
    blank = @property.select{ _1.essential and @value[_1].nil? }
    unless blank.empty?
      raise "cannot be omitted #{blank.map(&:long).join(',')}"
    end
    if self[:help]
      puts "Options:"
      puts help.gsub(/^/, '  ')
      puts
      exit
    end
  end

  def make!(...)
    make(...)
    ARGV.clear
  end

  def help
    matrix = @property.map do |p|
      [
        (p.essential ? '!' : ''),
        (p.short ? "-#{p.short}" : ''),
        "--#{p.long}",
        "#{p.description}#{(p.boolean ? ' (boolean)' : '')}",
      ]
    end
    longest = matrix.transpose.map{ _1.map(&:to_s).map(&:size).max }
    matrix.map do |row|
      "%-*s %-*s %-*s %-*s" % longest.zip(row).flatten
    end.join "\n"
  end

  def inspect
    a = @property.map do |p|
      "--#{p.long} #{@value&.[](p).inspect} <- #{@buffer[p].inspect}"
    end
    a.push "  bare #{@bare.inspect}"
    if @value.nil?
      a.push "This instance isn't available until the make() is called."
    end
    a.join "\n"
  end

  # Flatten the nested hashes and
  # change the key to dot notation.
  def self.dot_notation hash, ancestor=[ ]
    result = { }
    for key,value in hash
      present = ancestor + [key]
      if value.is_a? Hash and !value.empty?
        result.merge! dot_notation value, present
      else
        result.merge! present.join('.') => value
      end
    end
    result
  end
  private_class_method :dot_notation
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Option Element

class B::Option::Property < B::Structure
  attr_reader   :long        # String
  attr_reader   :short       # String ( single letter )
  attr_reader   :description # String
  attr_reader   :boolean     # true / false
  attr_reader   :essential   # true / false
  attr_reader   :normalizer  # any object that has a call() method
  attr_accessor :default     # anything

  def long= o
    @long = o.to_s
  end

  def short= o
    if o.length != 1
      raise "#{@long}: Mustbe a single letter `#{o}`"
    end
    if o =~ /[0-9]/
      raise "#{@long}: Numbers cannot be used for short option `#{o}`"
    end
    @short = o.to_s
  end

  def boolean= o
    unless o==true or o==false
      raise "#{@long}: boolean must be a true or false"
    end
    @boolean = o
  end

  def normalizer= o
    if o.is_a? Symbol or o.is_a? String
      unless B::Option::Normalizer.respond_to? o
        raise "#{@long}: invalid built-in normalizer #{o}"
      end
      @normalizer = B::Option::Normalizer.method o
    else
      unless o.respond_to? :call
        raise "#{@long}: normalizer must have a call() method"
      end
      @normalizer = o
    end
  end

  def essential= o
    unless o==true or o==false
      raise "#{@long}: essential must be a true or false"
    end
    @essential = o
  end

  def description= o
    @description = o.to_s
  end

  def hash
    @long.hash
  end

  def == other
    self.hash == other.hash
  end
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# built-in normalizers

module B::Option::Normalizer
  module_function

  def to_integer s
    return nil if s.is_a? Integer
    raise "Isn't String #{s}(#{s.class})" unless s.is_a? String
    raise "doesn't look like a Integer" if s !~ /^[+-]?\d+$/
    s.to_i
  end

  def to_float s
    return nil if s.is_a? Float
    raise "Isn't String #{s}(#{s.class})" unless s.is_a? String
    raise "doesn't look like a Float" if s !~ /^[+-]?\d+(?:\.\d+)?$/
    s.to_f
  end
end

