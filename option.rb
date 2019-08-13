
require 'optparse'

module B
  # for namespace
end

class B::Option
  @@program_name = nil
  @@version      = nil
  def self.program_name
    @@program_name
  end
  def self.version
    @@version
  end
  def self.program_name= s
    @@program_name = s
  end
  def self.version= s
    @@version = s
  end

  def initialize hash
    @legal  = hash.to_h{ |k,v| [k.to_sym, v] }.freeze
    @op     = OptionParser.new
    @switch = { }
    @bare   = [ ]

    @op.program_name   = @@program_name unless @@program_name.nil?
    @op.version        = @@version      unless @@version.nil?
    @op.summary_indent = ''

    for name,type in @legal
      unless type.is_a? Class or type.is_a? Array
        raise "must be a class => #{type}"
      end

      singleton = <<-"EoE"
        Proc.new do |x|
          if @switch.key? :'#{name}'
            puts "multiple definition of '--#{name}'"
            exit
          end
          @switch[:'#{name}'] = x
        end
      EoE
      multiton = <<-"EoE"
        Proc.new do |x|
          unless @switch.key? :'#{name}'
            @switch[:'#{name}'] = [ ]
          end
          @switch[:'#{name}'].push x
        end
      EoE

      if type.instance_of? Array
        if type.size != 1
          raise "don't set multiple type => #{type.inspect}"
        end
        type = type.first
        if type==TrueClass
          @op.on("--[no-]#{name}",    type, eval(multiton))
        else
          @op.on("--#{name} #{type}", type, eval(multiton))
        end
      else
        if type==TrueClass
          @op.on("--[no-]#{name}",    type, eval(singleton))
        else
          @op.on("--#{name} #{type}", type, eval(singleton))
        end
      end
    end
    @op.separator ''

    @op.parse! ARGV
    unless ARGV.empty?
      @bare = ARGV.clone
      ARGV.clear
    end
  end

  def underlay hash
    for name,value in hash
      name = name.to_sym
      raise_if_unknown_option name
      unless @switch.key? name
        @switch[name] = value
      end
    end
  end

  def blame_lack *keys
    lack = keys.flatten.map(&:to_sym) - @switch.keys
    unless lack.empty?
      ilist = lack.map{ |x| "    --#{x}\n" }.join
      puts 'These options can not be omitted:'
      puts ilist
      puts
      help_and_exit
    end
  end

  def blame_excess
    unless @bare.empty?
      puts 'Excess parameter(s):'
      puts @bare.map{ |i| i.gsub(/^/, '    ') }
      puts
      help_and_exit
    end
  end

  def bare
    @bare
  end

  def [] k
    k = k.to_sym
    raise_if_unknown_option k
    @switch[k]
  end

  def []= k, v
    k = k.to_sym
    raise_if_unknown_option k
    @switch[k] = v
  end

  def key? k
    @switch.key? k.to_sym
  end
  alias :has_key? :key?

  def to_h
    @switch.clone
  end
  alias :to_hash :to_h

  def slice *keys
    @switch.slice(*keys.flatten.map(&:to_sym))
  end

  def raise_if_unknown_option k
    unless @legal.key? k#.to_sym
      raise "unknown option => #{k}"
    end
  end

  def help_and_exit
    puts @op.help
    exit 1
  end

  def inspect
    m = @legal.keys.map(&:length).max
    @legal.keys.map do |k|
      "--%-*s = %s" % [m, k, @switch[k].inspect]
    end.join("\n")
  end
end
