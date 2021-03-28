
require 'toml'
require_relative 'b.path.rb'
require_relative 'name.rb'
require_relative 'job.rb'

class Recipe

  # Key in TOML => Arguments of the Job#initialize
  Correspondence = {
    'd' => :directory,
    'c' => :command,
    'o' => :option,
    'i' => :interval,
    'm' => :mutex,
  }.freeze

  def self.new_job_from_hash name, h
    excess = h.except(*Correspondence.keys)
    unless excess.empty?
      raise KeyError, "extra elements -> #{excess.inspect}"
    end
    Job.new(name:name, **h.transform_keys(Correspondence))
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

  def self.pluck_off_leaves toh
    result_a = [ ]
    result_h = { }
    for k in toh.keys.select{ toh[_1].is_a? Hash }
      r = pluck_off_leaves toh[k]
      if r.empty?
        result_a.push k
      else
        result_h[k] = r
      end
    end
    unless result_h.empty?
      result_a.push result_h
    end
    return result_a
  end

  #- - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  attr_reader :name # Name
  attr_reader :path # B::Path
  attr_reader :time # Time
  attr_reader :job  # Array[ Job ]
  attr_reader :node # Array, Hash, or nil

  def initialize path
    @path = B::Path.new path
    @name = Name.new @path.basename '.*'
    @job  = [ ]
    @node = nil
  end

  def unload!
    @job.each &:terminate
    @job.clear
    @node = nil
    return self
  end

  def load!
    unload!
    tree  = TOML.load_file @path
    leaf  = self.class.nourished_leaves tree, [@name]
    @node = self.class.pluck_off_leaves tree
    @job.replace leaf.map(&self.class.method(:new_job_from_hash))
    @time = @path.mtime
    return self
  end

  def missing?
    not @path.exist?
  end

  def modified?
    @time != @path.mtime
  end

  def inspect
    [
      "name: #{@name.inspect}",
      "path: #{@path.inspect}",
      "time: #{@time.inspect}",
      "job:  #{@job.map &:name}",
    ].join("\n")
  end
end

