#! /usr/bin/env ruby

require_relative 'b.log.rb'
require_relative 'b.option.rb'
require_relative 'b.trap.rb'
require_relative 'node-instance.rb'

begin
  opt = B::Option.new(
    'daemonize' => 'Run as a daemon',
    'bind'      => 'DRb binding IP',
    'port'      => 'DRb port',
    'log.age'   => 'Log rotation age',
    'log.size'  => 'Log file size',
    'toml'      => 'toml config',
  )
  opt.short(
    'daemonize' => :d,
    'bind'      => :b,
    'port'      => :p,
    'toml'      => :t,
  )
  opt.boolean 'daemonize'
  opt.normalizer(
    'port'      => :to_integer,
    'log.age'   => :to_integer,
    'log.size'  => :to_integer,
    'toml'      => -> { B::Path.xdgfind _1, :config }
  )
  opt.default(
    'bind'      => '0.0.0.0',
    'port'      => 57133,
    'log.age'   => 5,
    'log.size'  => 1_000_000,
    'toml'      => 'stim.toml',
  )
  opt.make!
rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

# XDG
path_pid     = B::Path.xdgvisit('pid.stim.pid', :cache)
path_log     = B::Path.xdgvisit('log.stim.log', :cache)
path_capture = B::Path.xdgvisit('stim/', :cache).dig
path_cfgd    = B::Path.xdgvisit('stim/', :config).dig

#- Daemon
if opt['daemonize']
  if path_pid.exist?
    STDERR.puts "file '#{path_pid}' already exists."
    STDERR.puts
    exit 1
  end
  Process.daemon true
  path_pid.write $$
  at_exit do
    path_pid.unlink rescue nil
  end
end

#- Log
log = B::Log.new(
  file:   (opt['daemonize'] ? path_log : STDOUT),
  format: '%m-%d %T',
  age:    opt['log.age'],
  size:   opt['log.size'],
)
log.i "Process started. PID=#{$$}"

at_exit do
  sleep 1
  log.i "Process terminated. PID=#{$$}"
  log.gap
end

#- Trap
B.trap do
  Node.eject
end

#- Main
begin
  Node.init(
    bind:    opt['bind'],
    port:    opt['port'],
    cfgdir:  path_cfgd,
    capture: path_capture,
    log:     log
  )

  for f in Node.configfiles + opt.bare
    Node.load_toml f
  end

  Node.start
  Node.join

rescue Exception => err
  log.f [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end

