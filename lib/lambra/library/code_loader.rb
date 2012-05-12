module Lambra
  class CodeLoader
    def self.evaluate(string)
      ast = Lambra::Parser.parse string
      execute(ast)
    end

    def self.execute(ast)
      visitor = BytecodeCompiler.new
      gen     = visitor.compile(ast)
      gen.encode
      cm = gen.package Rubinius::CompiledMethod

      require_relative '../bootstrap'

      env = Scope

      file = if ast.respond_to?(:filename) && ast.filename
        ast.filename
      else
        '(eval)'
      end

      line, binding, instance = ast.line, env.send(:binding), env

      # cm       = Noscript::Compiler.compile_eval(code, binding.variables, file, line)
      cm.scope = Rubinius::StaticScope.new(GlobalScope)
      cm.name  = :__lambra__
      script   = Rubinius::CompiledMethod::Script.new(cm, file, true)
      be       = Rubinius::BlockEnvironment.new

      script.eval_binding = binding
      # script.eval_source  = string
      cm.scope.script     = script

      be.under_context(binding.variables, cm)
      be.from_eval!
      be.call_on_instance(instance)
    end

    def self.execute_file(name)
      ast = Lambra::Parser.parse IO.read(name)
      def ast.filename; name; end
      execute(ast)
    end
  end
end
