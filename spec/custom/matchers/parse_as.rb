class ParseAsMatcher
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    @actual = Lambra::Parser.parse_to_sexp actual, true
    @actual == @expected
  end

  def failure_message
    ["Expected:\n#{@actual.inspect}\n",
     "to equal:\n#{@expected.inspect}"]
  end
end

class Object
  def parse_as(sexp)
    ParseAsMatcher.new sexp
  end
end
