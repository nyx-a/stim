#! /usr/bin/env ruby

require_relative 'log.rb'
require_relative 'controller.rb'
require_relative 'property.rb'
require_relative 'trapper.rb'

#- Option
begin
  opt = B::Property.new(
    'Daemonize'   => B::Boolean,
    'bindIp'      => String,
    'port'        => Integer,
    'dir-home'    => B::Path,
    'dir-capture' => String,
    'file-log'    => String,
    'file-pid'    => String,
    'log-age'     => Integer,
    'log-size'    => Integer,
    'help'        => B::Boolean,
  )
  opt.default(
    'Daemonize'   => false,
    'bindIp'      => '127.0.0.1',
    'port'        => 57133,
    'dir-home'    => '~/.stim.d',
    'dir-capture' => 'capture',
    'file-log'    => 'log.stim.log',
    'file-pid'    => 'num.stim.pid',
    'log-age'     => 5,
    'log-size'    => 1_000_000,
  )
  opt.description(
    'Daemonize'   => 'run as a daemon',
    'bindIp'      => 'drb binding IP',
    'port'        => 'drb port',
    'dir-home'    => 'home directory for stim',
    'dir-capture' => 'capture directory',
    'file-log'    => 'log file',
    'file-pid'    => 'pid file',
    'log-age'     => 'log rotation age',
    'log-size'    => 'log file size',
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

  opt['dir-home'].prepare_dir
  path_pid  = opt['dir-home'] + opt['file-pid']
  path_log  = opt['dir-home'] + opt['file-log']
  path_capd = opt['dir-home'] + opt['dir-capture']
  path_capd.prepare_dir
rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

#- Daemon
if opt['Daemonize']
  if path_pid.exist?
    STDERR.puts "file '#{path_pid.expand_s}' already exists."
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
  path_log.expand_s,
  format: '%m-%d %T',
  age:    opt['log-age'],
  size:   opt['log-size'],
)
log.i "Process started. PID=#{$$}"
at_exit do
  log.i "Process terminated. PID=#{$$}"
  log.gap
end

#- Main
begin

  s = Controller.new path_capd, 30, log, opt['bindIp'], opt['port']

  Trapper.procedure = -> signal do
    puts "#{signal} Trapped."
    s.eject_all
  end

  for f in opt.bare
    log.i "Loading configure file: '#{f}'"
    s.load f
  end

  at_exit do
    s.stop_all
    puts 'bye.'
  end

  opt['Daemonize'] ? Trapper.sleep : binding.irb

rescue Exception => err
  log.f [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end

