#! /usr/bin/env ruby

require_relative 'src/b.log.rb'
require_relative 'src/b.option.rb'
require_relative 'src/b.trap.rb'
require_relative 'src/manager.rb'

begin
  opt = B::Option.new(
    'daemonize' => 'Run as a daemon',
    'bind'      => 'DRb binding IP',
    'port'      => 'DRb port',
    'log.age'   => 'Log rotation age',
    'log.size'  => 'Log file size',
  )
  opt.short(
    'daemonize' => :d,
    'bind'      => :b,
    'port'      => :p,
  )
  opt.boolean 'daemonize'
  opt.normalizer(
    'port'      => :to_integer,
    'log.age'   => :to_integer,
    'log.size'  => :to_integer,
  )
  opt.default(
    'bind'      => '0.0.0.0',
    'port'      => 57133,
    'log.age'   => 5,
    'log.size'  => 1_000_000,
  )
  opt.make!
rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

#- Pathes
dir_cache   =  B::Path.dig '~/.cache'
file_log    = (B::Path.dig('~/.log') + 'log.stim.log')
file_pid    = (dir_cache + 'pid.stim.pid')
dir_capture = (dir_cache + 'stim').dig

#- Daemon
if opt['daemonize']
  if file_pid.exist?
    STDERR.puts "file '#{file_pid}' already exists."
    STDERR.puts
    exit 1
  end
  Process.daemon true
  file_pid.write $$
  at_exit do
    file_pid.unlink rescue nil
  end
end

#- Log
log = B::Log.new(
  (opt['daemonize'] ? file_log : STDOUT),
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

#- Main
begin
  manager = Manager.new(
    bind:    opt['bind'],
    port:    opt['port'],
    capture: dir_capture,
    log:     log
  )
  # B.trap{ manager.eject }
  manager.add_recipe opt.bare
  loop{ manager.wait_for_event }

rescue Exception => err
  log.f [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end

