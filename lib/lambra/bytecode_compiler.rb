module Lambra
  class BytecodeCompiler
    attr_reader :generator
    alias g generator

    SPECIAL_FORMS = %w(def fn let spawn receive match)
    PRIMITIVE_FORMS = %w(println + - / * send sleep self)

    def initialize(generator=nil)
      @generator = generator || RBX::Generator.new
    end

    def compile(ast, variables=nil, debugging=false)
      if debugging
        require 'pp'
        pp ast.to_sexp
      end

      if ast.respond_to?(:filename) && ast.filename
        g.file = ast.filename.to_sym
      else
        g.file = :"(lambra)"
      end

      line = ast.line || 1
      g.set_line line

      if variables
        g.push_state variables
      else
        g.push_state RBX::AST::ClosedScope.new(line)
      end

      ast.accept(self)

      debug if debugging
      g.ret

      finalize
    end

    def visit_EvalExpression(o)
      register_main_process
      o.body.accept(self)
    end
    alias_method :visit_Script, :visit_EvalExpression

    def register_main_process
      g.push_cpath_top
      g.find_const :Lambra
      g.find_const :Process

      g.push_cpath_top
      g.find_const :Lambra
      g.find_const :Process
      g.send :new, 0

      g.send :register, 1
    end

    def visit_List(o)
      set_line(o)
      return g.push_nil if o.elements.count.zero?
      car = o.elements[0]
      cdr = o.elements[1..-1]

      return visit_SpecialForm(car.name, cdr) if car.respond_to?(:name) && special_form?(car.name)
      return visit_PrimitiveForm(car.name, cdr) if car.respond_to?(:name) && primitive_form?(car.name)
      return visit_InteropForm(car.name, cdr) if car.respond_to?(:name) && interop_form?(car.name)

      args = cdr.count

      car.accept(self)

      cdr.each do |arg|
        arg.accept(self)
      end

      g.send :call, args
    end

    def visit_InteropForm(car, cdr)
      method = car[1..-1].to_sym
      receiver = cdr.shift
      receiver.accept(self)
      cdr.each do |argument|
        argument.accept(self)
      end

      g.send method, cdr.count, false
    end

    def visit_SpecialForm(car, cdr)
      case car.to_s
      when 'def'
        name = cdr.shift.name

        cdr.first.accept(self)

        local = g.state.scope.new_local(name)
        local.reference.set_bytecode(g)
      when 'fn'
        args_vector = cdr.shift
        arguments = Lambra::AST::ClosureArguments.new(args_vector.line, args_vector.column, args_vector)
        body = cdr.size > 1 ? Lambra::AST::Sequence.new(cdr.first.line, cdr.first.column, cdr) : cdr.shift
        closure = Lambra::AST::Closure.new(arguments.line, arguments.column, arguments, body)

        closure.accept(self)
      when 'let'
        args_vector = cdr.shift
        arguments = Lambra::AST::LetArguments.new(args_vector.line, args_vector.column, args_vector)
        body = cdr.size > 1 ? Lambra::AST::Sequence.new(cdr.first.line, cdr.first.column, cdr) : cdr.shift
        closure = Lambra::AST::Closure.new(arguments.line, arguments.column, arguments, body)

        closure.accept(self)

        arguments.values.each do |value|
          value.accept(self)
        end

        g.send :call, arguments.count
      when 'spawn'
        g.push_cpath_top
        g.find_const :Lambra
        g.find_const :Process

        fn = cdr.shift
        fn.accept(self)

        g.send_with_block :spawn, 0

      when 'receive'
        Lambra::AST::Receive.new(cdr).accept(self)
      when 'match'
        value = cdr.shift
        args_vector = Lambra::AST::Vector.new(value.line, value.column, [Lambra::AST::Symbol.new(value.line, value.column, :__value__)])
        arguments = Lambra::AST::ClosureArguments.new(value.line, value.column, args_vector)
        body = Lambra::AST::Match.new(value.line, value.column, cdr)
        closure = Lambra::AST::Closure.new(arguments.line, arguments.column, arguments, body)

        closure.accept(self)
        value.accept(self)
        # g.inspect
        g.send :call, 1
      end
    end

    def visit_Closure(o)
      set_line(o)

      state = g.state
      state.scope.nest_scope o

      blk_compiler = BytecodeCompiler.new(new_block_generator g, o.arguments)
      blk = blk_compiler.generator

      blk.push_state o
      blk.state.push_super state.super
      blk.state.push_eval state.eval

      blk.state.push_name blk.name

      o.arguments.accept(blk_compiler)
      blk.state.push_block
      o.body.accept(blk_compiler)
      blk.state.pop_block
      blk.ret
      blk_compiler.finalize

      g.create_block blk
    end

    def visit_ClosureArguments(o)
      args = o.arguments

      args.each_with_index do |a, i|
        # TIXME
        g.shift_array
        local = g.state.scope.new_local(a.name)
        g.set_local local.slot
        g.pop
      end
      g.pop unless args.empty?
    end

    alias_method :visit_LetArguments, :visit_ClosureArguments

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

    def visit_Symbol(o)
      if o.name.to_sym == :self
        return visit_Self(o)
      elsif o.name =~ /^[A-Z]/
        return visit_Constant(o)
      end

      set_line(o)

      local = g.state.scope.search_local(o.name)
      if local
        local.get_bytecode(g)
      else
        raise "unbound symbol #{o.name}"
      end
    end

    def visit_Self(o)
      g.push_process
      g.send :pid, 0
    end

    def visit_Constant(o)
      g.push_cpath_top
      o.name.to_s.split('.').each do |part|
        g.find_const(part.to_sym)
      end
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

      elems = o.elements.compact
      elems.each_with_index do |element, idx|
        element.accept(self)
        g.pop unless elems.count - 1 == idx
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

    def visit_Receive(o)
      args_vector = o.pattern
      arguments = Lambra::AST::ClosureArguments.new(args_vector.line, args_vector.column, args_vector)
      cdr = o.actions
      body = cdr.size > 1 ? Lambra::AST::Sequence.new(cdr.first.line, cdr.first.column, cdr) : cdr.shift
      closure = Lambra::AST::Closure.new(arguments.line, arguments.column, arguments, body)

      closure.accept(self)

      g.push_process
      g.send :pop, 0
      g.send :contents, 0

      arguments.arguments.each do |value|
        g.shift_array
        g.swap_stack
      end
      g.pop

      g.send :call, arguments.count
    end

    def visit_Match(o)
      local = g.state.scope.search_local(:__value__)
      local.get_bytecode(g)

      success = g.new_label
      done = g.new_label

      o.patterns.each_with_index do |pattern, idx|
        failure = g.new_label
        g.dup_top

        pattern.match(self, failure)
        pattern.execute(self, success)

        failure.set!
      end

      g.push_cpath_top
      g.find_const :ArgumentError
      g.push_literal "Pattern match failed"
      g.send :new, 1
      g.raise_exc
      g.goto done

      success.set!
      done.set!
    end

    def finalize
      g.local_names = g.state.scope.local_names
      g.local_count = g.state.scope.local_count
      g.pop_state
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
        instruct = RBX::InstructionSet[instruction]
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

    def interop_form?(name)
      !!(name =~ /^./)
    end

    def new_block_generator(g, arguments)
      blk = g.class.new
      blk.name = g.state.name || :__block__
      blk.file = g.file
      blk.for_block = true

      blk.required_args = arguments.count
      blk.post_args = arguments.count
      blk.total_args = arguments.count
      blk.cast_for_multi_block_arg unless arguments.count.zero?

      blk
    end
  end
end
