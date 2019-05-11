
require 'optparse'

class Option
  def initialize hash
    @sw = { }
    @op = OptionParser.new
    @ex = [ ]

    @op.summary_indent = ''

    for name,type in hash
      unless type.is_a? Class or type.is_a? Array
        raise "must be a class => '#{type}'"
      end

      name = name.to_s

      singleton = <<-"EoE"
        Proc.new do |x|
          if @sw.key? '#{name}'
            puts "multiple definition of '--#{name}'"
            exit
          end
          @sw['#{name}'] = x
        end
      EoE
      multiton = <<-"EoE"
        Proc.new do |x|
          unless @sw.key? '#{name}'
            @sw['#{name}'] = [ ]
          end
          @sw['#{name}'].push x
        end
      EoE

      if type.instance_of? Array
        if type.size != 1
          raise "don't set multiple type => #{type.inspect}"
        end
        type = type.first
        if type==TrueClass
          @op.on("--#{name}",         type, eval(multiton))
        else
          @op.on("--#{name} #{type}", type, eval(multiton))
        end
      else
        if type==TrueClass
          @op.on("--#{name}",         type, eval(singleton))
        else
          @op.on("--#{name} #{type}", type, eval(singleton))
        end
      end
    end
    @op.separator ''

    @op.parse! ARGV
    unless ARGV.empty?
      @ex = ARGV.clone
      ARGV.clear
    end
  end

  def underlay hash
    for name,value in hash
      name = name.to_s
      # unless @sw.has_key? name
      #   raise "unknown option => '#{name}'"
      # end
      unless @sw.has_key? name
        @sw[name] = value
      end
    end
  end

  def blame_lack *key
    blame = key.select{ |k| self.blank? k }
    unless blame.empty?
      ilist = blame.map{ |x| "    --#{x}\n" }.join
      puts 'These options can not be omitted:'
      puts ilist
      puts
      help!
    end
  end

  def blame_excess
    unless @ex.empty?
      puts 'Excess parameter(s):'
      puts @ex.map{ |i| i.gsub(/^/, '    ') }
      puts
      self.help!
    end
  end

  def excess
    @ex
  end

  def [] key
    @sw.fetch(key.to_s) { raise "unknown key => '#{key}'" }
  end

  def []= key, value
    @sw[key.to_s] = value
  end

  def blank? key
    !@sw.key? key
  end

  def help!
    puts @op.help
    exit
  end

  def inspect
    m = @sw.keys.map(&:length).max
    @sw.map do |k,v|
      "--%-*s = %s" % [m, k, v.inspect]
    end.join("\n")
  end
end

