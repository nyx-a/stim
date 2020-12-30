
require_relative 'b.structure.rb'

module B
end

class B::Option
end

class B::Option::Property < B::Structure
  attr_reader :long        # String
  attr_reader :short       # String ( single letter )
  attr_reader :description # String
  attr_reader :boolean     # true / false
  attr_reader :essential   # true / false
  attr_reader :normalizer  # any object that has a call() method

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
      if B::Option::Normalizer.respond_to? o
        @normalizer = B::Option::Normalizer.method o
      else
        raise "#{@long}: invalid built-in normalizer #{o}"
      end
    else
      if o.respond_to? :call
        @normalizer = o
      else
        raise "#{@long}: normalizer must have a call() method"
      end
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
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

class B::Option

  # h is { long => description }
  def initialize **h
    @bare   = [ ]
    @long   = { } # "long"   => Property
    @short  = { } # "short"  => Property
    @buffer = { } # Property => "buffer"
    @value  = nil # Property => value
    for l,d in h
      register_long Property.new long:l, description:d
    end
    unless @long.key? 'help'
      register_long Property.new(
        long:    'help',
        boolean: true,
      )
    end
  end

  def register_long p
    raise "long key is nil" if p.long.nil?
    raise "long key `#{p.long}` duplicated" if @long.key? p.long
    @long[p.long] = p
  end

  def register_short p
    raise "short key is nil" if p.short.nil?
    raise "short key `#{p.short}` duplicated" if @short.key? p.short
    @short[p.short] = p
  end

  def fetch_long l
    @long[l.to_s] or raise "invalid long option --#{l}"
  end

  def fetch_short s
    @short[s.to_s] or raise "invalid short option -#{s}"
  end

  def [] l
    if @value.nil?
      raise "#{self.class} is not available until the make() is called"
    end
    @value[fetch_long l]
  end

  def short **hsh # { long => short }
    hsh.each do
      p = fetch_long _1
      p.short = _2
      register_short p
    end
  end

  def boolean *arr # [ long ]
    arr.each{ fetch_long(_1).boolean = true }
  end

  def normalizer **hsh # { long => normalizer }
    hsh.each{ fetch_long(_1).normalizer = _2 }
  end

  def essential *arr # [ long ]
    arr.each{ fetch_long(_1).essential = true }
  end

  def default **hsh # { long => "default" }
    hsh.each{ @buffer[fetch_long _1] = _2 }
  end

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
        p = fetch_long $~.post_match
        raise "#{p.long} is not boolean" unless p.boolean
        @buffer[p] = false
        @bare.push second if second
      when /^--(?=[^-])/
        # --long
        p = fetch_long $~.post_match
        if p.boolean
          @buffer[p] = true
          @bare.push second if second
        else
          @buffer[p] = second || ''
        end
      when /^-(?=[^-])(?!.*[0-9])/
        # -short
        b,o = $~.post_match.chars.map{ fetch_short _1 }.partition(&:boolean)
        b.each{ @buffer[_1] = true }
        @buffer[o.pop] = second if second && !o.empty?
        o.each{ @buffer[_1] = '' }
      else
        # bare
        @bare.push first
      end
    end
    @bare.concat tail if tail
  end

  def make toml_file_path=nil
    @value = { } # <-- here
    parse ARGV
    for p in @long.values.filter{ @buffer.key? _1 }
      begin
        # If the normalizer returns nil,
        # the original string will be used as is.
        # ( Verification only, no conversion. )
        @value[p] = p.normalizer&.call(@buffer[p]) || @buffer[p]
      rescue Exception => e
        raise %Q`verification failed --#{p.long} "#{@buffer[p]}" #{e.message}`
      end
    end
    for p in @long.values.filter{ _1.essential }
      if @value[p].nil? or @value[p].empty?
        raise "cannot be omitted --#{p.long}"
      end
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
    matrix = @long.values.map do |p|
      [
        (p.essential ? '!' : ''),
        (p.short ? "-#{p.short}" : ''),
        "--#{p.long}",
        (p.boolean ? 'T/F' : ''),
        p.description,
        @value[p].inspect,
      ]
    end
    longest = matrix.transpose.map{ _1.map(&:to_s).map(&:size).max }
    matrix.map do |row|
      "%-*s %-*s %-*s %-*s .. %-*s" % longest.zip(row).flatten
    end.join "\n"
  end

  def inspect
    a = @long.map do |l,p|
      "--#{l} #{@value&.[](p).inspect} <- #{@buffer[p].inspect}"
    end
    a.push "  bare #{@bare.inspect}"
    a.join "\n"
  end
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# built-in normalizers

module B::Option::Normalizer
  module_function

  def to_integer s
    if s !~ /^[+-]?\d+$/
      raise "doesn't look like a Integer"
    end
    s.to_i
  end

  def to_float s
    if s !~ /^[+-]?\d+(?:\.\d+)?$/
      raise "doesn't look like a Float"
    end
    s.to_f
  end
end

