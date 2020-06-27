#! /usr/bin/env ruby

require_relative 'b.log.rb'
require_relative 'b.property.rb'
require_relative 'controller.rb'

#- Option
begin
  opt = B::Property.new(
    'daemonize'   => B::Boolean,
    'bindIp'      => String,
    'port'        => Integer,
    'home'        => B::Path,
    'capture'     => String,
    'file-log'    => String,
    'file-pid'    => String,
    'log-age'     => Integer,
    'log-size'    => Integer,
    'log-level'   => Symbol,
    'help'        => B::Boolean,
  )
  opt.default(
    'daemonize'   => false,
    'bindIp'      => '127.0.0.1',
    'port'        => 57133,
    'home'        => '~/.stim.d',
    'capture'     => 'capture',
    'file-log'    => 'log.stim.log',
    'file-pid'    => 'num.stim.pid',
    'log-age'     => 5,
    'log-size'    => 1_000_000,
    'log-level'   => 'Information',
  )
  opt.description(
    'daemonize'   => 'run as a daemon',
    'bindIp'      => 'drb binding IP',
    'port'        => 'drb port',
    'home'        => 'home directory for stim',
    'capture'     => 'capture directory',
    'file-log'    => 'log file',
    'file-pid'    => 'pid file',
    'log-age'     => 'log rotation age',
    'log-size'    => 'log file size',
    'log-level'   => 'log level',
    'help'        => 'show this message',
  )

  opt.parse_option ARGV
  if opt['help']
    puts "Usage:"
    puts "  $ #{$0} options and files"
    puts "Options:"
    puts opt.help indent:2
    puts
    exit
  end

  opt['home'].expand!.prepare_dir!
  path_pid  = opt['home'] + opt['file-pid']
  path_log  = opt['home'] + opt['file-log']
  path_capd = opt['home'] + opt['capture']
  path_capd.prepare_dir!
rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

#- Daemon
if opt['daemonize']
  if path_pid.exist?
    STDERR.puts "file '#{path_pid.to_s}' already exists."
    STDERR.puts
    exit 1
  end
  Process.daemon true
  path_pid.write $$
  at_exit do
    path_pid.delete rescue nil
  end
end

#- Log
log = B::Log.new(
  file:   (opt['daemonize'] ? path_log.to_s : STDOUT),
  format: '%m-%d %T',
  age:    opt['log-age'],
  size:   opt['log-size'],
)
log.i "Process started. PID=#{$$}"
log.loglevel = opt['log-level']
log.i "Loglevel changed to #{opt['log-level']}"
at_exit do
  sleep 1
  log.i "Process terminated. PID=#{$$}"
  log.gap
end

#- Main
begin
  s = Controller.new(
    path_capd,
    30,
    log,
    opt['bindIp'],
    opt['port'],
    opt['home'],
  )
  for f in opt.bare
    s.load f
  end

  at_exit do
    s.stop_all
  end
  s.sleep

rescue Exception => err
  log.f [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end

