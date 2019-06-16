
require_relative 'stim-class.rb'


def check_dir path
  path = File.expand_path path
  if File.exist? path
    if File.directory? path
      if File.writable? path
        # ok
      else
        raise "not writable => '#{path}'"
      end
    else
      raise "not directory => '#{path}'"
    end
  else
    FileUtils.mkpath path
  end
  return path
end


#- options
begin
  opt = B::Option.new(
    'test'              => TrueClass,
    'daemon'            => TrueClass,
    'capture.directory' => String,
    'Capture.age'       => Integer,
    'log.directory'     => String,
    'Log.age'           => Integer,
    'Log.size'          => Integer,
  )

  opt.underlay(
    'daemon'            => true,
    'capture.directory' => './capture',
    'Capture.age'       => 20,
    'log.directory'     => './log',
    'Log.age'           => 5,
    'Log.size'          => 1_000_000,
  )

  if opt['test']
    opt['daemon'] = false
  end

  opt['capture.directory'] = check_dir opt['capture.directory']

rescue OptionParser::ParseError => err
  STDERR.puts err.message
  STDERR.puts
  exit 1
end

#- log
unless opt['daemon']
  opt['log.directory'] = nil
  output = STDOUT
else
  opt['log.directory'] = check_dir opt['log.directory']
  output = File.join opt['log.directory'], 'log.stim.log'
end
log = B::Log.new(
  output,
  f:    '%m-%d %T',
  age:  opt['Log.age'],
  size: opt['Log.size']
)

#- daemon
if opt['daemon']
  pidfile = 'pid.stim.pid'
  if File.exist? pidfile
    STDERR.puts "file '#{pidfile}' already exists."
    STDERR.puts
    exit 1
  end
  Process.daemon true
  File.write pidfile, $$
end

#-
begin
  log.i "Process Started%s. PID=%d" % [
    (opt['daemon'] ? ' as a daemon' : ''),
    $$,
  ]
  log.blank

  log.i("Options:\n" + opt.inspect)
  log.blank

  stim = Stimming.new(
    logger:       log,
    captureDir:   opt['capture.directory'],
    captureLimit: opt['Capture.age']
  )

  unless opt.excess.empty?
    for f in opt.excess
      log.i "Reading configure file: '#{f}'"
      c = stim.readconfig f
      log.i " -> #{c} node#{c>1 ? 's' : ''}."
    end
    log.blank
  end

  if opt['test']
    log.d "Option '--test' is true."
  elsif !stim.empty?
    log.i stim.inspect
    log.blank

    stim.open_backdoor sout:log.method(:i)

    B::Trap.add do
      sleep
      log.d '(Signal INT/TERM received.)'
    end

    stim.startall
    stim.joinall
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

if opt['daemon'] and File.exist? pidfile
  File.delete pidfile
end

log.i "Process Terminated. PID=#{$$}"
log.gap
