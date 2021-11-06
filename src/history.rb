
require 'yaml'
require_relative 'result.rb'

#
#* Serializable Capped Array ( for Result )
#

class History
  def initialize register, limit:30
    @mutex    = Mutex.new
    @limit    = limit
    @array    = [ ]
    @register = register
    load
  end

  def push nr
    if !@array.empty? and nr.same_as @array.last
      nr.unlink :dup
    end
    @mutex.synchronize do
      @array.push nr
      while @array.size > @limit
        @array.shift.unlink :expire
      end
    end
    return self
  end

  # to built-in basic types
  def to_b
    @mutex.synchronize do
      @array.map do |i|
        B::Structure.to_h i, k:'to_s', v:->{
          case _1
          when B::Enum then _1.value
          when B::Path then _1.to_s
          else _1
          end
        }
      end
    end
  end

  def save
    data = to_b
    unless data.empty?
      @mutex.synchronize do
        open(@register, 'w+'){ _1.write YAML::dump data }
      end
    end
  end

  def load
    @mutex.synchronize do
      if File.exist? @register and !File.zero? @register
        @array.replace self.class.load_yaml @register
      end
    end
  end

  def self.load_yaml path
    str = File.read path
    obj = Psych.safe_load str, permitted_classes:[Time, Symbol]
    obj.map{ Result.new(**_1) }
  end
end

