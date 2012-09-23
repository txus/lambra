module Lambra
  class BytecodeCompiler
    class Scope
      attr_reader :variables, :generator
      alias g generator

      def initialize(generator, parent=nil)
        @parent    = parent
        @variables = []
        @generator = generator
      end

      def slot_for(name)
        if existing = @variables.index(name)
          existing
        else
          @variables << name
          @variables.size - 1
        end
      end

      def push_variable(name, current_depth = 0, g = self.g)
        if existing = @variables.index(name)
          if current_depth.zero?
            g.push_local existing
          else
            g.push_local_depth current_depth, existing
          end
        else
          @parent.push_variable(name, current_depth + 1, g)
        end
      end

      def set_variable(name, current_depth = 0, g = self.g)
        if existing = @variables.index(name)
          if current_depth.zero?
            g.set_local existing
          else
            g.set_local_depth current_depth, existing
          end
        else
          @parent.set_variable(name, current_depth + 1, g)
        end
      end

      def set_local(name)
        slot = slot_for(name)
        g.set_local slot
      end
    end

    attr_reader :generator, :scope
    alias g generator
    alias s scope

    SPECIAL_FORMS = %w(def fn)
    PRIMITIVE_FORMS = %w(println + - / *)

    def initialize(parent=nil)
      @generator = Rubinius::Generator.new
      parent_scope = parent ? parent.scope : nil
      @scope = Scope.new(@generator, parent_scope)
    end

    def compile(ast, debugging=false)
      if debugging
        require 'pp'
        pp ast.to_sexp
      end

      if ast.respond_to?(:filename) && ast.filename
        g.file = ast.filename.to_sym
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
      car = o.elements[0]
      cdr = o.elements[1..-1]

      return visit_SpecialForm(car.name, cdr) if car.respond_to?(:name) && special_form?(car.name)
      return visit_PrimitiveForm(car.name, cdr) if car.respond_to?(:name) && primitive_form?(car.name)

      args = cdr.count

      car.accept(self)

      cdr.each do |arg|
        arg.accept(self)
      end

      g.send :call, args
    end

    def visit_SpecialForm(car, cdr)
      case car.to_s
      when 'def'
        name = cdr.shift.name

        cdr.first.accept(self)
        s.set_local name
      when 'fn'
        args = cdr.shift # a Vector
        argcount = args.elements.size

        # Get a new compiler
        block = BytecodeCompiler.new(self)

        # Configures the new generator
        # TODO Move this to a method on the compiler
        block.generator.for_block = true
        block.generator.total_args = argcount
        block.generator.required_args = argcount
        block.generator.post_args = argcount
        block.generator.cast_for_multi_block_arg unless argcount.zero?
        block.generator.set_line args.line

        block.visit_arguments(args.elements)
        cdr.shift.accept(block)
        block.generator.ret

        g.push_const :Function
        # Invoke the create block instruction
        # with the generator of the block compiler
        g.create_block block.finalize
        g.send :new, 1
      end
    end

    def visit_PrimitiveForm(car, cdr)
      g.push_cpath_top
      g.find_const :Primitives
      g.push_literal car
      g.send :get, 1

      cdr.each do |arg|
        arg.accept(self)
      end

      g.send :call, cdr.count
    end

    def visit_arguments(args)
      args.each_with_index do |a, i|
        g.shift_array
        s.set_local a.name
        g.pop
      end
      g.pop unless args.empty?
    end

    def visit_Symbol(o)
      set_line(o)
      s.push_variable o.name
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

    def visit_Keyword(o)
      set_line(o)
      g.push_cpath_top
      g.find_const :Keyword
      g.push_literal o.name
      g.send :new, 1
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

    def visit_Set(o)
      set_line(o)

      g.push_cpath_top
      g.find_const :Set

      count = o.elements.count
      o.elements.each do |elem|
        elem.accept(self)
      end
      g.make_array count

      g.send :new, 1
    end

    def visit_Map(o)
      set_line(o)

      ary   = o.to_a
      count = ary.size
      i = 0

      g.push_cpath_top
      g.find_const :Hash
      g.push count # / 2
      g.send :new_from_literal, 1

      while i < count
        k = ary[i].first
        v = ary[i].last

        g.dup
        k.accept(self)
        v.accept(self)
        g.send :[]=, 2
        g.pop

        i += 1
      end
    end

    def finalize
      g.local_names = s.variables
      g.local_count = s.variables.size
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

    private

    def special_form?(name)
      SPECIAL_FORMS.include?(name.to_s)
    end

    def primitive_form?(name)
      PRIMITIVE_FORMS.include?(name.to_s)
    end
  end
end
