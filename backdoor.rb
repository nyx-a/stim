
require 'socket'

module B
  # for namespace
end

module B::Backdoor
  attr_reader :backdoor_port
  attr_reader :backdoor_thread

  BACKDOOR_ALLOW = {
    help: 'show this message',
    bye:  'close connection',
  }

  def backdoor_allow
    self.class.const_get :BACKDOOR_ALLOW
  end

  def read_eval_return message
    token = message.split
    if token.empty?
      return ""
    end
    command = token.shift.to_sym
    unless backdoor_allow.include? command
      return %(invalid command `#{command}`)
    end
    begin
      method(command).call(*token)&.to_s
    rescue Exception => ex
      [
        ex.message,
        '(' + ex.class.name + ')',
        # ex.backtrace,
      ].join("\n")
    end
  end

  def open_backdoor(
    prompt:'- ',
    # set parameters nil for quiet run
    sout:STDOUT.method(:puts),
    eout:STDERR.method(:puts)
  )
    sv = TCPServer.open("", 0)
    @backdoor_port = sv.addr[1]
    sout&.call "maintenance port is #{@backdoor_port}"
    @backdoor_thread = Thread.new do
      loop do
        con = sv.accept
        rip = con.remote_address.ip_address
        rpt = con.remote_address.ip_port
        sout&.call "(Client #{rip}:#{rpt} connected.)"

        until con.closed?
          con.write (prompt.is_a?(Proc) ? prompt.call : prompt).to_s
          message = con.gets
          break if message.nil?
          sout&.call " < #{message.inspect}"

          reply = read_eval_return message

          if reply.nil?
            con.close
          elsif !reply.empty?
            con.write reply + "\n\n"
            sout&.call " > #{reply.inspect}"
          end
        end
        sout&.call "(Client #{rip}:#{rpt} is gone.)"
      end
    end
    #@backdoor_thread.abort_on_exception = true
    return @backdoor_thread
  end

  def help *options
    e = backdoor_allow.keys
    m = e.map(&:length).max
    e.map do |k|
      "%*s - %s" % [m, k, backdoor_allow[k]]
    end.join("\n")
  end

  def bye *options
    nil
  end
end

if __FILE__ == $0
  class Foo
    include B::Backdoor
    attr_accessor :value
  end
  foo = Foo.new
  foo.value = -> { Time.now.to_s + ' $ ' }
  foo.open_backdoor prompt:foo.value
  foo.backdoor_thread.join
end
