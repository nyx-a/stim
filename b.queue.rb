
module B
  # for namespace
end

# Priority Queue
class B::QP
  def initialize n=1
    @number     = n
    @thread     = [ ]
    @queue      = Queue.new
    @entrance   = Mutex.new # for inbound
    @plist      = [ ]
  end

  def queue_remaining
    @queue.size
  end

  def start &block
    unless block_given?
      raise 'No Block Given'
    end
    (@number - @thread.size).times do
      newthread = Thread.new do
        while object = @queue.shift
          block.call(object)
        end
      end
      @thread.push newthread
    end
  end

  def stop
    @entrance.synchronize do
      @thread.size.times do
        @queue.push nil
      end
      until @thread.empty?
        @thread.shift.join
      end
    end
  end

  def push object
    return if !object
    @entrance.synchronize do
      if @plist.empty? or pexclude?(object)
        @queue.push object
      else
        temporary = [ ]
        begin
          @queue.size.times do
            temporary.push @queue.shift(true)
          end
        rescue ThreadError
          # possible exception
        end
        temporary.push object
        i = 0
        temporary.sort_by! { |o| [pindex(o), i+=1] }
        for t in temporary
          @queue.push t
        end
      end
    end
  end

  def priority
    @plist
  end

  def priority= l
    @plist.replace l
  end

  protected

  def pexclude? object
    @plist.detect{ |p| p === object }.nil?
  end

  def pindex object
    i = @plist.find_index{ |p| p === object }
    i.nil? ? @plist.size : i
  end
end
