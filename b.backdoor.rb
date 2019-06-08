
require 'socket'

module B
  # for namespace
end

module B::BackDoor
  def open_backdoor(
    sout:STDOUT.method(:puts),
    eout:STDERR.method(:puts)
  )
    sv = TCPServer.open("", 0)
    @backdoor_port = sv.addr[1]
    sout.call "maintenance port is #{@backdoor_port}"
    loop do
      Thread.new sv.accept do |con|
        rip = con.remote_address.ip_address
        rpt = con.remote_address.ip_port
        sout.call "(connected #{rip}:#{rpt})"
        while message=con.gets
          sout.call " << #{message.inspect}"
          result = backdoor_repl message
          sout.call ">>  #{result.inspect}"
          con.write result
        end
        con.close
        sout.call "(disconnected #{rip}:#{rpt})"
      end
    end
  end

  def backdoor_repl args
    if args =~ /\w/
      args.upcase.gsub(/\s+/) { '!!' + $& }
    else
      ''
    end
  end
end
