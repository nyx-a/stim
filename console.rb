#! /usr/bin/env ruby

require 'reline'
require 'colorize'
require_relative 'src/b.option.rb'
require_relative 'src/b.path.rb'
require_relative 'src/socket-helper.rb'
require_relative 'src/name.rb'

def rainbow s
  c = String.colors - %i(black light_black default white light_white)
  s.chars.map{
    _1.colorize c.sample # , mode: :swap
  }.join
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

begin
  opt = B::Option.new(
    'host' => 'host',
    'port' => 'port',
  )
  opt.short(
    'host' => :h,
    'port' => :p,
  )
  opt.default(
    'host' => '127.0.0.1',
    'port' => 57133,
  )
  opt.make!
rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

#- - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

prompt = ':)'.colorize(mode: :swap) + ' '

socket = TCPSocket.open opt[:host], opt[:port]
socket.extend SocketHelper
info = socket.recv_object

Reline.completion_proc = -> s do
  r = Regexp.new Regexp.quote s
  b = Reline.line_editor.whole_buffer
  if b !~ /\s/
    info[:verb].grep(r).map{ _1 + ' ' }
  else
    info[:noun].grep r
  end
end

puts rainbow 'Welcome to stim console'
puts "Host #{socket.opponent}"
puts "You  #{socket.me}"
puts

while buffer = Reline.readline(prompt, true)
  unless buffer.empty?
    socket.w buffer
    puts socket.r
    puts
  end
end

