class CompileAsMatcher
  def initialize(expected)
    @expected = expected
  end

  def matches?(actual)
    ast     = Lambra::Parser.parse actual
    visitor = Lambra::BytecodeCompiler.new
    visitor.compile(ast)

    @actual = visitor.generator
    @expected.literals == @actual.literals &&
      @expected.stream == @actual.stream
  end

  def failure_message
    instruction_to_name = lambda do |i|
      instruct = Rubinius::InstructionSet[i]
      instruct.name
    end

    actual_stream   = @actual.stream.map(&instruction_to_name)
    expected_stream = @expected.stream.map(&instruction_to_name)

    actual_literals = @actual.literals.map(&:inspect).join(', ')
    expected_literals = @expected.literals.map(&:inspect).join(', ')

    ["Expected:\n\t#{actual_stream.join("\n\t")}\nLITERALS: #{actual_literals}\n",
     "to equal:\n\t#{expected_stream.join("\n\t")}\nLITERALS: #{expected_literals}"]
  end
end

class Object
  def compile_as(generator, *plugins)
    CompileAsMatcher.new generator
  end
end
