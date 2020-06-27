
require 'yaml'
require_relative 'b.path.rb'

module B

  #
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
  #

  class Boolean
    def initialize s
      @b = parse s
    end
    def parse s
      case s
      when true,  /^\s*(?:t|true |on |yes)\s*$/ix; true
      when false, /^\s*(?:f|false|off|no )\s*$/ix; false
      else
        raise "Doesn't look like a Boolean `#{s}`"
      end
    end
    def on!
      @b = true
    end
    def off!
      @b = false
    end
    def toggle!
      @b = !@b
    end
    def to_b # to built-in
      @b
    end
    def to_s
      @b ? 'True' : 'False'
    end
    def inspect
      to_s
    end
  end

  #
  #- - - - - - - - - - - - - - - - - - - - - - - - - - - -
  #

  class Item
    attr_reader :key
    attr_reader :type
    attr_reader :short # single letter alias of key
    attr_reader :is_plural
    attr_reader :checker
    attr_reader :default
    attr_reader :value
    attr_reader :description

    def key= k
      @key = k.to_sym
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
      @short = s
    end

    def is_plural= p
      case
      when true,false,nil
        @is_plural = p
      else
        raise "(#{@key}) is_plural mustbe true/false `#{p}`"
      end
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
             v.to_i
           elsif @type == Float
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
          raise [
            "[#{@key}] Rejected by checker",
            @checker.inspect,
            "`#{nv.inspect}`",
          ].join(' ')
        end
      end
      return @is_plural ? [nv] : nv
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

    def << v
      nv = self.normalize v
      if @value.nil?
        @value = nv
      else
        if @is_plural
          @value.concat nv
        else
          raise "Crowding values for `#{@key}`"
        end
      end
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
      is_plural:   nil,
      checker:     nil,
      default:     nil,
      value:       nil,
      description: nil
    )
      self.key         = key
      self.type        = type
      self.short       = short
      self.is_plural   = is_plural
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

  class Property
    attr_reader :bare

    def initialize key_type_hash
      @bare      = [ ]
      @contents  = { } # :longkey  => Item
      @shorthash = { } # :shortkey => Item
      for k,t in key_type_hash
        self.add key:k, type:t
      end
    end

    def add(
      key:,
      type:        nil,
      short:       nil,
      is_plural:   nil,
      checker:     nil,
      default:     nil,
      value:       nil,
      description: nil
    )
      key = key.to_sym
      item = Item.new(
        key:         key,
        type:        type,
        short:       short.to_sym,
        is_plural:   is_plural,
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

    def short key_short_hash
      for k,s in key_short_hash
        fetch(k).short = s.to_sym
      end
    end

    def multiply *keys
      for k in keys
        fetch(k).is_plural = true
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

    def parse_option array
      @bare.clear
      eoo = array.index '--' # end of options
      if eoo
        @bare = array[ eoo+1 .. -1    ]
        array = array[ 0     .. eoo-1 ]
      end

      current = nil
      for v in array
        op_sym = key_identify v
        if op_sym.nil?
          if current.nil?
            @bare.push v
          else
            @contents[current] << v
            current = nil
          end
        else
          @contents[current].flip! if current
          current = op_sym
        end
      end
      @contents[current].flip! if current
    end

    # non option token -> nil
    # valid option     -> Symbol
    def key_identify token
      case token
      when /^-+$/
        nil
      when /^--/
        $'.to_sym if fetch $'
      when /^-(?!-)/
        fetch_short($')&.key
      else
        nil
      end
    end

    def fetch_short s
      s = s.to_sym
      unless @shorthash.key? s
        raise KeyError, "Unknown short key `#{s}`"
      end
      @shorthash[s]
    end

    def fetch k
      k = k.to_sym
      unless @contents.key? k
        raise KeyError, "Unknown key `#{k}`"
      end
      @contents[k]
    end

    def fetch! k
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

    def help indent:2
      matrix = @contents.map do |k,v|
        [
          "--#{k}#{v.is_plural ? '(*)' : ''}",
          v.type.name.split('::').last,
          v.default,
          v.description,
        ]
      end.reject{ |i| i[1].nil? }

      longest = matrix.transpose.map do |column|
        column.map(&:to_s).map(&:size).max
      end
      matrix.map do |row|
        (' ' * indent) +
          "%-*s %-*s ( %-*s ) %-*s" % longest.zip(row).flatten
      end.join "\n"
    end

    def inspect
      matrix = @contents.map do |k,v|
        [
          k,
          v.type&.inspect,
          v.value&.inspect,
          v.default&.inspect,
          v.checker&.inspect,
        ]
      end
      matrix.unshift %w(Key Type Value Default Checker)
      longest = matrix.transpose.map do |column|
        column.map(&:to_s).map(&:size).max
      end
      aos = matrix.map do |row|
        "|%-*s|%-*s|%-*s|%-*s|%-*s|" % longest.zip(row).flatten
      end
      bar = "+%s+%s+%s+%s+%s+" % longest.map{ |l| '-' * l }
      aos.insert(-1, bar)
      aos.insert( 1, bar)
      aos.insert( 0, bar)
      aos.push "Bare:#{@bare.inspect}"
      aos.join "\n"
    end
  end
end

