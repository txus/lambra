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

class EvalToKindOfMatcher
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = Lambra::CodeLoader.evaluate actual
    @actual.is_a?(@expected)
  end

  def failure_message
    ["Expected:\n#{@actual.inspect}\n",
     "to evaluate to a kind of:\n#{@expected.inspect}"]
  end
end

class Object
  def eval_to(result)
    EvalToMatcher.new result
  end

  def eval_to_kind_of(klass)
    EvalToKindOfMatcher.new klass
  end
end
