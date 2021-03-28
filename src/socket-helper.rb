
require 'socket'
require 'base64'

module SocketHelper
  def r
    s = self.gets("\0")&.delete_suffix("\0")
    if s
      Base64.strict_decode64 s
    end
  end

  def w s
    self.write Base64.strict_encode64(s || s.inspect), "\0"
  end

  def send_object o
    self.w Marshal.dump o
  end

  def recv_object
    Marshal.load self.r
  end

  def opponent
    p,h = Socket.unpack_sockaddr_in getpeername
    "#{h}:#{p}"
  end

  def me
    a = local_address
    "#{a.ip_address}:#{a.ip_port}"
  end
end

