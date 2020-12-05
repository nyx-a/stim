
require 'yaml'
require_relative 'b.boolean.rb'
require_relative 'b.path.rb'

module B
end

class B::Option
end

class B::Option::Item
  attr_reader :key
  attr_reader :type
  attr_reader :short # single letter alias
  attr_reader :checker
  attr_reader :default
  attr_reader :value
  attr_reader :description

  def key= k
    @key = k&.to_sym
  end

  def type= t
    if t != nil and t.class != Class
      raise "(#{@key}) Not a class `#{t}`"
    end
    @type = t
  end

  def short= s
    unless s.nil?
      if s.length != 1
        raise "(#{@key}) Short alias mustbe 1 letter `#{s}`"
      end
    end
    @short = s&.to_sym
  end

  def checker= c
    unless c.nil? or c.respond_to? :===
      raise [
        "(#{@key}) Checker object",
        "does not have a '===' method",
        "`#{c.inspect}`",
      ].join(' ')
    end
    @checker = c
  end

  def normalize v
    nv = if v.nil?
           nil
         elsif @type == v.class
           v.clone
         elsif @type == Integer
           if v !~ /\d/
             raise ArgumentError,
               "doesn't look like a Integer `#{v}`"
           end
           v.to_i
         elsif @type == Float
           if v !~ /\d/
             raise ArgumentError,
               "doesn't look like a Float `#{v}`"
           end
           v.to_f
         elsif @type == Symbol
           v.to_sym
         elsif @type == Regexp
           Regexp.new v
         elsif @type == B::Boolean
           B::Boolean.new v
         elsif @type == B::Path
           B::Path.new v
         else
           v.clone
         end
    unless @checker.nil?
      unless @checker === nv
        raise ArgumentError, [
          "[#{@key}] Rejected by checker",
          @checker.inspect,
          "`#{nv.inspect}`",
        ].join(' ')
      end
    end
    return nv
  end

  def value= v
    @value = self.normalize v
  end

  def default= v
    @default = self.normalize v
  end

  def description= d
    @description = d&.to_s
  end

  def flip!
    if @type == B::Boolean
      if self.projection
        if @value.nil?
          @value = B::Boolean.new false
        else
          @value.toggle!
        end
      else
        if @value.nil?
          @value = B::Boolean.new true
        else
          @value.toggle!
        end
      end
    else
      raise "Non-Boolean-Item cannot be flipped `#{@key}`"
    end
  end

  def initialize(
    key:         nil,
    type:        nil,
    short:       nil,
    checker:     nil,
    default:     nil,
    value:       nil,
    description: nil
  )
    self.key         = key
    self.type        = type
    self.short       = short
    self.checker     = checker
    self.default     = default
    self.value       = value
    self.description = description

    if @type == B::Boolean and @default.nil?
      self.default = false
    end
  end

  def projection
    p = @value || @default
    p.is_a?(B::Boolean) ? p.to_b : p
  end
end

#
#- - - - - - - - - - - - - - - - - - - - - - - - - - - -
#

class B::Option
  attr_reader :bare

  def initialize key_type_hash={ }
    @bare      = [ ]
    @contents  = { } # :longkey  => Item
    @shorthash = { } # :shortkey => Item
    for k,t in key_type_hash
      self.add key:k, type:t
    end
    unless @contents.key? :help
      self.add key: :help, type: B::Boolean
    end
  end

  def add(
    key:,
    type:        nil,
    short:       nil,
    checker:     nil,
    default:     nil,
    value:       nil,
    description: nil
  )
    key = key.to_sym
    if @contents.key? key
      raise "Key duplicated `#{key}`"
    end
    item = Item.new(
      key:         key,
      type:        type,
      short:       short,
      checker:     checker,
      default:     default,
      value:       value,
      description: description
    )
    @contents[key] = item
    if item.short
      if @shorthash.key? item.short
        raise "The short option is duplicated `#{item.short}`"
      else
        @shorthash[item.short] = item
      end
    end
  end

  def list_add *seq
    for i in seq.flatten
      self.add(**i)
    end
  end

  def short key_short_hash
    for k,s in key_short_hash
      s = s.to_sym
      i = fetch k
      i.short = s
      @shorthash[s] = i
    end
  end

  def default key_default_hash
    for k,d in key_default_hash
      fetch(k).default = d
    end
  end

  def checker key_checker_hash
    for k,c in key_checker_hash
      fetch(k).checker = c
    end
  end

  def description key_text_hash
    for k,t in key_text_hash
      fetch(k).description = t
    end
  end

  def parse array
    @bare.clear
    eoo = array.index '--' # end of options
    if eoo
      bare  = array[ eoo+1 .. -1    ]
      array = array[ 0     .. eoo-1 ]
    end
    re = /^-{1,2}(?=[^-])/
    for c in array.chunk_while{ |l,r| l =~ re and r !~ re }
      first  = c[0]
      second = c[1]
      case first
      when /^-{1}(?=[^-])/ # short
        letters = $~.post_match.chars
        if fetch_short(letters.last).type == B::Boolean
          @bare.push second if second
        else
          ll = letters.pop # last letter
          if second.nil?
            raise "No params for Non-Boolean-Item `#{ll}`"
          end
          fetch_short(ll).value = second
        end
        for b in letters
          fetch_short(b).flip!
        end
      when /^-{2}(?=[^-])/ # long
        op = $~.post_match
        if second.nil?
          fetch(op).flip!
        else
          fetch(op).value = second
        end
      else
        @bare.push first
      end
    end
    @bare.concat bare if bare

    if self[:help]
      self.show_help_and_exit
    end
  end

  def fetch_short s
    raise KeyError, "nil was given for key" if s.nil?
    s = s.to_sym
    unless @shorthash.key? s
      raise KeyError, "Unknown short key `#{s}`"
    end
    @shorthash[s]
  end

  def fetch k
    raise KeyError, "nil was given for key" if k.nil?
    k = k.to_sym
    unless @contents.key? k
      raise KeyError, "Unknown key `#{k}`"
    end
    @contents[k]
  end

  def fetch! k
    raise KeyError, "nil was given for key" if k.nil?
    k = k.to_sym
    @contents[k] or (@contents[k] = Item.new(key:k))
  end

  def [] k
    fetch(k).projection
  end

  def []= k, v
    fetch!(k).value = v
  end

  def raise_if_blank *keys
    keys = keys.flatten
    keys = @contents.keys if keys.empty?
    blankkeys = keys.select{ |k| self[k.to_sym].nil? }
    unless blankkeys.empty?
      raise ArgumentError, [
        "These keys cannot be omitted",
        "#{blankkeys.inspect}",
      ].join(' ')
    end
  end

  def underlay hash
    for k,v in hash
      fetch(k).value ||= v
    end
  end

  def yaml_underlay fname
    begin
      underlay YAML.load_file fname.to_s
    rescue => e
      raise "`#{e}` in file #{fname}"
    end
  end

  def overlay hash
    for k,v in hash
      fetch(k).value = v
    end
  end

  def yaml_overlay fname
    begin
      overlay YAML.load_file fname.to_s
    rescue => e
      raise "#{e} in file `#{fname}`"
    end
  end

  def slice *keys
    @contents.slice(*keys.flatten.map(&:to_sym)).to_h do |k,v|
      [ k, v.projection ]
    end.compact
  end

  def to_hash
    @contents.to_h do |k,v|
      [ k, v.projection ]
    end
  end

  def each(...)
    self.to_hash.each(...)
  end

  def show_help_and_exit o=STDOUT, indent:2
    o.puts self.help indent:indent
    o.puts
    Kernel.exit
  end

  def help indent:2
    matrix = @contents.select{_2.type}.map do |k,v|
      [
        "--#{k}",
        (v.short ? "-#{v.short}" : ""),
        v.type.name.split('::').last,
        v.projection,
        v.description,
      ]
    end
    longest = matrix.transpose.map do |column|
      column.map(&:to_s).map(&:size).max
    end
    matrix.map do |row|
      "#{' ' * indent}%-*s %*s %-*s ( %-*s ) %-*s" %
        longest.zip(row).flatten
    end.join "\n"
  end

  def inspect
    matrix = @contents.map do |k,v|
      [
        k,
        v.short,
        v.type&.name&.split('::')&.last,
        v.value&.inspect,
        v.default&.inspect,
        v.checker&.inspect,
        v.description&.to_s,
      ]
    end
    matrix.unshift %w(Key K Type Value Default Chk Desc)
    longest = matrix.transpose.map do |column|
      column.map(&:to_s).map(&:size).max
    end
    aos = matrix.map do |row|
      "|%-*s|%*s|%-*s|%-*s|%-*s|%-*s|%-*s|" %
        longest.zip(row).flatten
    end
    bar = "+%s+%s+%s+%s+%s+%s+%s+" % longest.map{|l| '-' * l}
    aos.insert(-1, bar)
    aos.insert( 1, bar)
    aos.insert( 0, bar)
    aos.push "Bare:#{@bare.inspect}"
    aos.join "\n"
  end
end

