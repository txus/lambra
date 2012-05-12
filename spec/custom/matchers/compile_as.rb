class CompileAsMatcher
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    ast     = Lambra::Parser.parse actual
    visitor = Lambra::BytecodeCompiler.new
    visitor.compile(ast)


    @actual = visitor.generator
    @expected.stream == @actual.stream
  end

  def failure_message
    ["Expected:\n#{@actual.stream.inspect}\n",
     "to equal:\n#{@expected.stream.inspect}"]
  end
end

class Object
  def compile_as(generator, *plugins)
    CompileAsMatcher.new generator
  end
end
