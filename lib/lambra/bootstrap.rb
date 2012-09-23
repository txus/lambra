require 'set'

class Function
  def initialize(&block)
    @block = block
  end

  def call(*args)
    @block.call(*args)
  end
end

module GlobalScope
  Bootstrap = {
      ##
      # Symbol                 Function body
      ##
      :println => Function.new { |*args| puts *args },
      :+       => Function.new { |*args| args.inject(:+) },
      :-       => Function.new { |*args| args.inject(:-) },
      :/       => Function.new { |a, b| a / b },
      :*       => Function.new { |a, b| a * b },
    }
end

Scope = GlobalScope::Bootstrap

class Keyword
  def initialize(name)
    @name = name
  end
end
