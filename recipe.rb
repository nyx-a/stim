
require 'toml'
require_relative 'b.path.rb'
require_relative 'name.rb'
require_relative 'node.rb'

class Recipe

  # Key in TOML => Arguments of the Node#initialize
  Correspondence = {
    'd' => :directory,
    'c' => :command,
    'o' => :option,
    'i' => :interval,
    'm' => :mutex,
  }.freeze

  def self.new_node_from_hash name, h
    excess = h.except(*Correspondence.keys)
    unless excess.empty?
      raise KeyError, "extra elements -> #{excess.inspect}"
    end
    Node.new(name:name, **h.transform_keys(Correspondence))
  end

  # toh is Tree of Hash
  # result is flatten leaves
  def self.nourished_leaves toh, ancestor=[], carry={}
    result = { }
    h,o    = toh.keys.partition{ toh[_1].is_a? Hash }
    carry  = carry.merge toh.slice(*o)
    if h.empty?
      result[Name.new ancestor] = carry
    else
      for k in h
        result.merge! nourished_leaves(
          toh[k],
          (ancestor + [k]),
          carry
        )
      end
    end
    return result
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :basename # Name
  attr_reader :path     # B::Path
  attr_reader :time     # Time
  attr_reader :node     # Array[ Node ]

  def initialize path
    @path     = B::Path.new path
    @basename = Name.new @path.basename '.*'
    @node     = [ ]
  end

  def unload!
    @node.each &:eject
    @node.clear
    return self
  end

  def load!
    tree = TOML.load_file @path
    leaf = self.class.nourished_leaves tree, [@basename]
    unload!
    @node.replace leaf.map(&self.class.method(:new_node_from_hash))
    @time = @path.mtime
    return self
  end

  def deleted?
    not @path.exist?
  end

  def modified?
    @time != @path.mtime
  end

  def inspect
    [
      "basename: #{@basename.inspect}",
      "path:     #{@path.inspect}",
      "time:     #{@time.inspect}",
      "node:     #{@node.map &:name}",
    ].join("\n")
  end
end

