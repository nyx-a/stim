
# - タプルは一ヶ所で全てtake()することにした
#   対象のワイルドカード指定が可能になった

# - 設定ファイルはディレクトリではなくファイル直接指定にした
#   recipeクラス追加

require 'rinda/tuplespace'
require_relative 'command.rb'
require_relative 'recipe.rb'
require_relative 'b.path.rb'
require_relative 'b.log.rb'

class Manager

  def initialize(
    bind:, port:, capture:, log:,
    refreshinterval:15, tupleexpire:3600, commandtimeout:3600
  )
    @alive           = true
    @refreshinterval = refreshinterval
    @tupleexpire     = tupleexpire
    @commandtimeout  = commandtimeout
    @recipe          = [ ]
    @log             = log
    @capture         = B::Path.new capture, confirm:'directory'
    @ts              = Rinda::TupleSpace.new @refreshinterval

    Node.capture = @capture
    Node.ts      = @ts
    Node.log     = @log

    DRb.start_service "druby://#{bind}:#{port}", @ts
    @log.i %Q`tuplespace is ready at "#{DRb.uri}"`
  end

  def add_recipe *path
    for p in path.flatten
      @log.d "#{__callee__}(#{p.inspect})"
      @recipe.push Recipe.new(p).load!
    end
  end

  # <- Array[ Recipe ]
  def recipe_grep name
    @recipe.select{ |r| r.basename === name }
  end

  # <- Array[ Node ]
  def node_grep name
    recipe_grep(name)
      .map{ |r| r.node.select{ |n| n.name === name } }
      .flatten
  end

  def take tuple
    h = @log.d @ts.take tuple.wildcard
    tuple.new(**h.transform_keys(&:to_sym))
  end

  def loop
    wait_for_event while @alive
  end

  def wait_for_event
    stimulus = take Stimulus
    nodes    = node_grep stimulus.to
    if nodes.empty?
      @log.e "Unknown destination -> #{stimulus.inspect}"
    else
      nodes.each(&stimulus.instr)
    end
  rescue => err
    @log.e err.inspect
  end

  def eject
    @recipe.each &:unload!
    @alive = false
  end

  # def wait_for_control
  #   control = take Control
  #   case control.ctrl.value
  #   when :recipes
  #     # r = recipe_grep Name.new control.args
  #   when :nodes
  #   when :reload
  #   end
  # end
end

