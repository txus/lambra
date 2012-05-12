require 'set'

class Function
  def initialize(&block)
    @block = block
  end
  def call(*args)
    @block.call(*args)
  end
end

class GlobalScope < Hash
  def self.bootstrap
    scope = new
    scope[:println] = Function.new { |*args| puts *args }
    scope[:+]       = Function.new { |*args| args.inject(:+) }
    scope[:-]       = Function.new { |*args| args.inject(:-) }
    scope[:/]       = Function.new { |a, b| a / b }
    scope[:*]       = Function.new { |a, b| a * b }
    scope
  end
end

Scope = GlobalScope.bootstrap

class Keyword
  def initialize(name)
    @name = name
  end
end
