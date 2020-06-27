
require_relative 'b.property.rb'
require_relative 'controller.rb'

O = B::Property.new(
  ip:   String,
  port: Integer,
)
O.default(
  ip:   '127.0.0.1',
  port: 57133,
)

s = DRbObject.new_with_uri "druby://#{O[:ip]}:#{O[:port]}"

print "Jobs -> "
pp s.job.keys
print "Error -> "
pp s.history.select{ |x| x.status != 0 }
binding.irb

