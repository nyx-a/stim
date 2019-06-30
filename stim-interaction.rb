
require 'b/backdoor.rb'

class Stimming
  include B::Backdoor

  BACKDOOR_ALLOW = BACKDOOR_ALLOW.merge(
    terminate:      'terminate daemon',
    inspect:        'inspect all nodes',
    readconfig:     'read configure file',
    running_nodes:  'show running nodes PID',
    uptime:         'show uptimes',
  )

  def uptime
    @list_all.to_h{ |k,v| [k, Time.now - v.start_time] }.compact
  end

  def terminate
    B::Trap.hand_interrupt
    nil
  end
end

