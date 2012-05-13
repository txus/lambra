class EvalToMatcher
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = Lambra::CodeLoader.evaluate actual
    @actual == @expected
  end

  def failure_message
    ["Expected:\n#{@actual.inspect}\n",
     "to evaluate to:\n#{@expected.inspect}"]
  end
end

class Object
  def eval_to(result)
    EvalToMatcher.new result
  end
end
