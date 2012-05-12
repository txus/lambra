module Lambra
  class CodeLoader
    def self.evaluate(string)
      ast     = Lambra::Parser.parse string
      visitor = BytecodeCompiler.new
      cm      = visitor.compile(ast)
    end

    def self.execute_file(name)
      value = Lambra::Parser.parse IO.read(name)
      p value
    end
  end
end
