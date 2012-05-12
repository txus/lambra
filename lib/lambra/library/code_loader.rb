module Lambra
  class CodeLoader
    def self.evaluate(string)
      ast     = Lambra::Parser.parse string
      visitor = BytecodeCompiler.new
      cm      = visitor.compile(ast)
    end

    def self.execute_file(name)
      ast = Lambra::Parser.parse IO.read(name)
      def ast.filename; name; end
      visitor = BytecodeCompiler.new
      cm      = visitor.compile(ast)
    end
  end
end
