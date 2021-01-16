
require 'toml'
require 'rinda/tuplespace'
require_relative 'b.structure.rb'
require_relative 'command.rb'


class Node < B::Structure

  RefreshInterval = 15
  TupleExpire     = 3600

  @@log   = nil
  @@ts    = Rinda::TupleSpace.new RefreshInterval
  @@mutex = { } # { ? => Mutex }

  def self.get_mutex token
    if token.nil?
      nil
    else
      token = token.to_s
      @@mutex.fetch(token){ @@mutex[token] = Mutex.new }
    end
  end

  def self.init bind:, port:, cfgdir:, capture:, log:
    @@cfgdir   = cfgdir.undoubtedly :directory
    @@capture  = capture.undoubtedly :directory
    @@log      = log
    @@table    = { } # { B::Path => [ Node ] }
    DRb.start_service "druby://#{bind}:#{port}", @@ts
    @@log.i %Q`tuplespace is ready at "#{DRb.uri}"`
  end

  def self.start
    for e in @@table.values.flatten
      e.start_thread
      sleep 1
    end
  end

  def self.eject
    @@table.values.flatten.each{ _1.issue 'eject' }
  end

  def self.join
    @@table.values.flatten.each &:wait_close
  end

  #
  #* TOML configure files
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

  def self.unload_toml path
    @@log.i "unload: #{path}"
    @@table[path].each{ _1.issue 'eject' }
    @@table[path].each{ _1.wait_close  }
  end

  def self.load_toml path
    basename = File.basename path, '.*'
    tree     = TOML.load_file path
    flatten  = nest_projection tree, [basename]
    if @@table.key? path
      unload_toml path
    end
    @@log.i "load: #{path}"
    @@table[path] = flatten.map do |k,v|
      raise unless v.except(*%w|d c o i m|).empty?
      dco = v.slice(*%w|d c o|).transform_keys(&:to_sym)
      Node.new(
        name:      k,
        command:   Command.new(**dco),
        interval:  v['i'],
        mutex:     v['m'],
      )
    end
  rescue => err
    @@log.e [
      err.message,
      '(' + err.class.name + ')',
      err.backtrace,
    ].join("\n")
  end

  def self.configfiles
    Dir.glob(@@cfgdir + '*.toml').map{ B::Path.new _1, confirm:nil }
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

