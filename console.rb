#! /usr/bin/env ruby

require 'readline'
require 'rinda/tuplespace'
require_relative 'b.option.rb'
require_relative 'b.path.rb'
require_relative 'tuple.rb'

begin
  opt = B::Option.new(
    'host' => 'DRb host',
    'port' => 'DRb port',
    'toml' => 'TOML file name',
  )
  opt.short(
    'host' => :b,
    'port' => :p,
    'toml' => :t,
  )
  opt.default(
    'host' => '127.0.0.1',
    'port' => 57133,
    'toml' => B::Path.xdgfind('stim.toml', :config),
  )
  opt.make!
rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

uri = "druby://#{opt[:host]}:#{opt[:port]}"
puts
puts '    ' + uri.inspect
puts

DRb.start_service
ts = Rinda::TupleSpaceProxy.new DRbObject.new_with_uri uri

while buffer = Readline.readline("> ", true)

  array = buffer.split

  case array.first
  when /terminate/
    ###
  when /stimulus/
    pp ts.read_all Stimulus.wildcard
  when /report/
    pp ts.read_all Report.wildcard
  when /run/
    ts.write Stimulus[to:array[1], instr:'execute']
  end
end

