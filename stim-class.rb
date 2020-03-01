
require 'yaml'
require_relative 'log.rb'
require_relative 'timelength.rb'
require_relative 'trap.rb'
require_relative 'backdoor.rb'
require_relative 'stim-misc.rb'
require_relative 'stim-node.rb'

class Stimming
  include B::Backdoor

  BACKDOOR_ALLOW = BACKDOOR_ALLOW.merge(
    terminate:      'terminate daemon',
    inspect:        'inspect all nodes',
    running_nodes:  'show running nodes PID',
    read_yaml:      'read configure file',
    read_yamls:     'read configure file(*)',
    execute:        'execute node(s)',
  )

  def initialize log:, cap:
    @list    = { } # "name" => Node
    @log     = log
    @capture = cap
  end

  def getnode names
    names.map do |n|
      @list.fetch(n){ |k| raise NoSuchNode, k }
    end
  end

  def running_nodes
    @list.to_h{ |k,v| [k, v.pid] }.compact
  end

  def terminate
    B::Trap.hand_interrupt
    nil
  end

  def execute *names
    getnode(names).map do |o|
      raise "can't execute dependent node." if o.need_replace
      o.execute
    end
  end

  def read_yamls script
    bdir = File.dirname script
    sum = 0
    open(script).read.each_line(chomp:true) do |line|
      for fn in Dir.glob(line, base:bdir)
        sum += read_yaml File.join(bdir, fn)
      end
    end
    return sum
  end

  def read_yaml ymlpath
    yml = YAML.load_file ymlpath
    for dir,entry in yml
      dir = File.expand_path dir.to_s, File.dirname(ymlpath)
      Stimming.raise_if_invalid_directory dir
      for name,field in entry
        name = name.to_s
        field = field.to_h{ |k,v| [k, v.to_s] }

        field['c'] = Stimming.tidyup_path field['c']
        Stimming.raise_if_invalid_command dir, field['c']

        interval = nil
        if field.key? 't'
          begin
            opt_t = getnode Stimming.tokenize field['t']
          rescue NoSuchNode
            interval = B::TimeLength.new field['t']
          end
        end

        waiting = Stimming.scan_tokens field['o']
        need_replace = !waiting.empty?
        waiting.push opt_t.map(&:name) unless opt_t.nil?
        waiting.uniq!
        parent = getnode waiting.flatten.uniq

        if !parent.empty? and !interval.nil?
          raise TriggerDuplicated, name
        elsif !interval.nil?
          nodetype = :interval
        elsif !parent.empty?
          nodetype = :event
        else
          nodetype = :hand
        end

        newnode = Node.new(
          name:         name,
          directory:    dir,
          command:      field['c'],
          options:      field['o'] || "",
          waiting:      waiting,
          parent:       parent,
          nodetype:     nodetype,
          need_replace: need_replace,
          interval:     interval,
          log:          @log,
          capture:      @capture,
        )
        parent.each{ |p| p.child.append newnode }
        @list[name] = newnode
      end
    end
    @list.size
  end

  def waterfall
    @list.each_value(&__callee__)
    self
  end
  alias :pause :waterfall
  alias :stop  :waterfall
  alias :join  :waterfall
  undef :waterfall

  def start t=nil
    @list.each_value do |n|
      n.start t
      sleep 1
    end
    self
  end

  def touch
    @list.each_value do |n|
      if n.nodetype != :event
        @thread = Thread.new { n.execute }
        sleep 1
      end
    end
  end

  def empty?
    @list.empty?
  end

  def inspect
    if @list.empty?
      'empty nodes.'
    else
      @list.values.map(&:inspect).join("\n")
    end
  end
end
