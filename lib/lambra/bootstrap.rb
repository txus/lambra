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
  def self.bootstrap
    {
      :println => Function.new { |*args| puts *args },
      :+       => Function.new { |*args| args.inject(:+) },
      :-       => Function.new { |*args| args.inject(:-) },
      :/       => Function.new { |a, b| a / b },
      :*       => Function.new { |a, b| a * b },
    }
  end
end

Scope = GlobalScope.bootstrap

class Keyword
  def initialize(name)
    @name = name
  end
end
