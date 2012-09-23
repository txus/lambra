require 'set'

class PrimitiveFunction
  def initialize(&block)
    @block = block
  end

  def call(*args)
    @block.call(*args)
  end
end

class Function
  def initialize(blk_env)
    @block_environment = blk_env
    @executable = blk_env.compiled_code
  end

  def call(*args)
    @executable.invoke(:anonymous, @executable.scope.module, Object.new, args, nil)
  end

  def to_proc
    Proc.__from_block__(@block_environment)
  end
end

class PrimitiveScope
  def initialize(bindings, parent=nil)
    @bindings = bindings
    @parent = parent
  end

  def get(name)
    @bindings[name] or (@parent && @parent.get(name)) or raise "Undefined primitive #{name} in scope #{self}"
  end

  def set(name, value)
    @bindings[name] = value
  end

  def to_s
    "#<PrimitiveScope @parent=#{@parent || 'nil'} #{@bindings}>"
  end
end

module GlobalScope
end

Primitives = PrimitiveScope.new({
  ##
  # Symbol                 Function body
  ##
  :println => PrimitiveFunction.new { |*args| puts *args },
  :+       => PrimitiveFunction.new { |*args| args.inject(:+) },
  :-       => PrimitiveFunction.new { |*args| args.inject(:-) },
  :/       => PrimitiveFunction.new { |a, b| a / b },
  :*       => PrimitiveFunction.new { |a, b| a * b },
})

class Keyword
  def initialize(name)
    @name = name
  end
end
