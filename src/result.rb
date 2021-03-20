
require_relative 'output.rb'

#
#* Result of Command#run
#

class Result < B::Structure
  attr_reader :pid    # Integer
  attr_reader :status # Integer or nil
  attr_reader :start  # Time
  attr_reader :end    # Time
  attr_reader :stdout # Output
  attr_reader :stderr # Output

  def pid= o
    @pid = o
  end

  def status= o
    @status = o
  end

  def start= o
    @start = o
  end

  def end= o
    @end = o
  end

  def stdout= o
    @stdout = Output.funnel o
  end

  def stderr= o
    @stderr = Output.funnel o
  end

  def time_spent
    if @end and @start
      @end - @start
    end
  end

  def unlink reason
    @stdout.unlink reason
    @stderr.unlink reason
  end

  def same_as o
    @stdout.same_as o.stdout and @stderr.same_as o.stderr
  end
end

