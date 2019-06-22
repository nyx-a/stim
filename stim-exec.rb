
require_relative 'stim-class.rb'
require_relative 'stim-func.rb'

#- options
begin
  opt = B::Option.new(
    'pretend'             => TrueClass,
    'directory'           => String,
    'x-file-pid'          => String,
    'x-file-log'          => String,
    'x-file-port'         => String,
    'x-capture-directory' => String,
    'x-capture-age'       => Integer,
    'x-log-age'           => Integer,
    'x-log-size'          => Integer,
  )

  opt.underlay(
    'directory'           => '~/.stim',
    'x-file-pid'          => 'pid.stim.pid',
    'x-file-log'          => 'log.stim.log',
    'x-file-port'         => 'port.stim.port',
    'x-capture-directory' => 'capture',
    'x-capture-age'       => 20,
    'x-log-age'           => 5,
    'x-log-size'          => 1_000_000,
  )

  opt['directory'] = prepare_dir opt['directory']
  cap_dir = prepare_dir(
    opt['directory'],
    opt['x-capture-directory']
  )
  path_pid  = File.join opt['directory'], opt['x-file-pid']
  path_log  = File.join opt['directory'], opt['x-file-log']
  path_port = File.join opt['directory'], opt['x-file-port']

rescue => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

#- pid
if File.exist? path_pid
  STDERR.puts "file '#{path_pid}' already exists."
  STDERR.puts
  exit 1
end
Process.daemon true
File.write path_pid, $$

#- log
log = B::Log.new(
  (opt['pretend'] ? STDOUT : path_log),
  format: '%m-%d %T',
  age:    opt['x-log-age'],
  size:   opt['x-log-size']
)

#-
begin
  log.i "Process Started. PID=#{$$}"
  log.blank

  log.i "Options:\n#{opt.inspect}"
  log.blank

  stim = Stimming.new(
    logger:       log,
    captureDir:   cap_dir,
    captureLimit: opt['x-capture-age']
  )

  unless opt.excess.empty?
    for f in opt.excess
      log.i "Reading configure file: '#{f}'"
      c = stim.readconfig f
      log.i " -> #{c} node#{c>1 ? 's' : ''}."
    end
    log.blank
  end

  if opt['pretend']
    log.d "Option '--pretend' is true."
  elsif !stim.empty?
    log.i stim.inspect
    log.blank

    stim.open_backdoor sout:log.method(:i)
    log.blank
    File.write path_port, stim.backdoor_port

    B::Trap.add do
      sleep
      log.d '(Signal INT/TERM received.)'
    end

    stim.startall
    stim.joinall
    B::Trap.join
  end
rescue Stimming::SlightError => err
  log.e err.message
rescue Exception => err
  log.e [
    err.message,
    '(' + err.class.name + ')',
    err.backtrace,
  ].join("\n")
end

File.delete path_pid if File.exist? path_pid
File.delete path_port if File.exist? path_port

log.i "Process Terminated. PID=#{$$}"
log.gap
