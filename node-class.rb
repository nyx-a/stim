
require 'toml'
require 'rinda/tuplespace'
require_relative 'b.structure.rb'
require_relative 'command.rb'

#
#
#

class Node < B::Structure

  RefreshInterval = 15
  TupleExpire     = 3600

  @@log   = nil
  @@ts    = Rinda::TupleSpace.new RefreshInterval
  @@mutex = { } # { ? => Mutex }

  def self.get_mutex s
    if s.nil?
      nil
    else
      s = s.to_s
      @@mutex.fetch(s){ @@mutex[s] = Mutex.new }
    end
  end

  def self.init bind:, port:, cfgdir:, capdir:, log:
    @@cfgdir   = cfgdir
    @@capdir   = capdir
    @@log      = log
    @@table    = { } # { B::Path => [ Node ] }
    DRb.start_service "druby://#{bind}:#{port}", @@ts
    @@log.i %Q`tuplespace is ready at "#{DRb.uri}"`
  end

  def self.start
    e = @@table.values.flat_map
    e.each do
      _1.start_thread
      sleep 1
    end
    e.each &:join_thread
  end

  #
  #* TOML
  #

  def self.nest_projection hash, ancestor=[], stack={}
    result = { }
    h,o = hash.keys.partition{ hash[_1].is_a? Hash }
    stack = stack.merge hash.slice(*o)
    if h.empty?
      result[Name.new ancestor] = stack
    else
      for key in h
        result.merge! nest_projection(
          hash[key],
          (ancestor + [key]),
          stack
        )
      end
    end
    result
  end

  def self.load_toml path
    basename = File.basename(path, '.*')
    tree     = TOML.load_file path
    flatten  = nest_projection tree, [basename]
    flatten.map do |k,v|
      ####raise unless v.except(*%w|d c o i m|).empty?
      dco = v.slice(*%w|d c o|).transform_keys(&:to_sym)
      Node.new(
        name:      k,
        command:   Command.new(**dco),
        interval:  v['i'],
        mutex:     v['m'],
      )
    end
  end

end

#
#
#

class Timekeeper
  def initialize sec
    @reference = sec
    @length = nil
    @start = nil
  end

  def active?
    not @start.nil?
  end

  def start # also a resume
    if @start.nil?
      if @length.nil? or @length.negative?
        @length = @reference
      end
      @start = Time.now
      @length
    end
  end

  def pause
    if @start
      if @length
        @length -= Time.now - @start
      end
      @start = nil
      @length
    end
  end

  def reset
    @length = nil
    @start  = nil
  end
end

