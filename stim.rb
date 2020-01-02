#! /usr/bin/env ruby

require_relative 'option.rb'
require_relative 'stim-class.rb'
require_relative 'stim-misc.rb'

begin
  opt = B::Option.new(
    '0-time'              => TrueClass,
    '1-time'              => TrueClass,
    'daemonize'           => TrueClass,
    'base'                => String,
    'x-file-autoload'     => String,
    'x-file-log'          => String,
    'x-file-pid'          => String,
    'x-file-port'         => String,
    'x-capture-directory' => String,
    'x-log-age'           => Integer,
    'x-log-size'          => Integer,
  )
  opt.underlay(
    '0-time'              => false,
    '1-time'              => false,
    'daemonize'           => false,
    'base'                => '~/.stim.d',
    'x-file-autoload'     => 'stimrc',
    'x-file-log'          => 'log.stim.log',
    'x-file-pid'          => 'num.stim.pid',
    'x-file-port'         => 'num.stim.port',
    'x-capture-directory' => 'capture',
    'x-log-age'           => 5,
    'x-log-size'          => 1_000_000,
  )
  opt['daemonize'] = false if opt['1-time'] or opt['0-time']
  opt['base'] = '.' if opt['1-time']

  path_rc   = Stimming::ejpath opt['base'], opt['x-file-autoload']
  path_pid  = Stimming::ejpath opt['base'], opt['x-file-pid']
  path_log  = Stimming::ejpath opt['base'], opt['x-file-log']
  path_port = Stimming::ejpath opt['base'], opt['x-file-port']

  opt['base'] = Stimming.prepare_dir opt['base']
  path_capd = Stimming.prepare_dir(
    opt['base'],
    opt['x-capture-directory']
  )
rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

verbose = opt['1-time'] ? false : true

if !opt['1-time'] and !opt['0-time']
  if File.exist? path_pid
    STDERR.puts "file '#{path_pid}' already exists."
    STDERR.puts
    exit 1
  end
  if opt['daemonize']
    Process.daemon true
  end
  File.write path_pid, $$
end

log = B::Log.new(
  (opt['daemonize'] ? path_log : STDOUT),
  format: '%m-%d %T',
  age:    opt['x-log-age'],
  size:   opt['x-log-size']
)

if verbose
  log.i "Process Started. PID=#{$$}"
  log.blank
  log.i "Options:\n#{opt.inspect}"
  log.blank
end

begin
  stim = Stimming.new log:log, cap:path_capd

  if opt.bare.empty?
    if File.exist? path_rc
      log.i "Auto loading: '#{path_rc}'"
      stim.read_yamls path_rc
    end
  else
    for f in opt.bare
      log.i "Reading configure file: '#{f}'"
      c = stim.read_yaml f
      log.i " -> #{c} Node#{c>1 ? 's' : ''}."
    end
    log.blank
  end

  if verbose
    log.i stim.inspect
    log.blank
  end

  if !stim.empty?
    case
    when opt['0-time']
      log.i "Option '--0-time' is true."
    when opt['1-time']
      stim.start :event
      stim.touch
      stim.stop
    else
      stim.open_backdoor(
        sout:log.method(:d),
        prompt:->{ "#{stim.running_nodes.size}> " },
      )
      log.blank
      File.write path_port, stim.backdoor_port
      B::Trap.add do
        sleep
        log.i '(Signal INT/TERM received.)'
        stim.stop
      end
      stim.start.join
      B::Trap.join
    end
  end
rescue Stimming::Error => err
  log.e err.message
rescue Exception => err
  log.e [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end

if !opt['1-time'] and !opt['0-time']
  File.delete path_pid if File.exist? path_pid
  File.delete path_port if File.exist? path_port
end

if verbose
  log.i "Process Terminated. PID=#{$$}"
  log.gap
end
