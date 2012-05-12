module Lambra
  class BytecodeCompiler
    attr_reader :generator
    alias g generator

    def initialize
      @generator = Rubinius::Generator.new
    end

    def compile(ast, debugging=false)
      if debugging
        require 'pp'
        pp ast.to_sexp
      end

      if ast.respond_to?(:filename) && ast.filename
        g.file = ast.filename
      else
        g.file = :"(lambra)"
      end

      g.set_line ast.line || 1

      ast.accept(self)

      debug if debugging
      g.ret

      finalize
    end

    def visit_List(o)
      set_line(o)
      return g.push_nil if o.elements.count.zero?
    end

    def visit_Number(o)
      set_line(o)
      g.push_literal o.value
    end

    def visit_Character(o)
      set_line(o)
      g.push_literal o.value
    end

    def visit_String(o)
      set_line(o)
      g.push_literal o.value
    end

    def visit_True(o)
      set_line(o)
      g.push_true
    end

    def visit_False(o)
      set_line(o)
      g.push_false
    end

    def visit_Nil(o)
      set_line(o)
      g.push_nil
    end

    def visit_Sequence(o)
      set_line(o)

      o.elements.compact.each do |element|
        element.accept(self)
      end
    end

    def visit_Vector(o)
      count = o.elements.size

      set_line(o)
      o.elements.each do |x|
        x.accept(self)
      end

      g.make_array count
    end

    def finalize
      # g.local_names = s.variables
      # g.local_count = s.variables.size
      g.close
      g
    end

    def set_line(o)
      g.set_line o.line if o.line
    end

    def debug(gen = self.g)
      p '*****'
      ip = 0
      while instruction = gen.stream[ip]
        instruct = Rubinius::InstructionSet[instruction]
        ip += instruct.size
        puts instruct.name
      end
      p '**end**'
    end
  end
end
