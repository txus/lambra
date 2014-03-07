require_relative 'scope'

module Lambra
  module AST
    module Visitable
      def accept(visitor, *args)
        name = self.class.name.split("::").last
        visitor.send "visit_#{name}", self, *args
      end
    end

    class Node
      include Visitable

      attr_reader :line, :column

      def sexp_name
        self.class.name.split('::').last.downcase.to_sym
      end

      def to_sexp
        [sexp_name]
      end
    end

    class Sequence < Node
      def to_sexp
        @elements.compact.map(&:to_sexp)
      end
    end

    class Number < Node
      def to_sexp
        [sexp_name, @value]
      end
    end

    class String < Node
      def to_sexp
        [sexp_name, @value]
      end
    end

    class Character < Node
      def to_sexp
        [sexp_name, @value]
      end
    end

    class Symbol < Node
      def to_sexp
        [sexp_name, @name]
      end
    end

    class Keyword < Node
      def to_sexp
        [sexp_name, @name]
      end
    end

    class List < Node
      def to_sexp
        [sexp_name,
          *@elements.map(&:to_sexp)]
      end
    end

    class Map < Node
      def to_sexp
        return super if @elements.empty?

        keys   = @elements.keys.map(&:to_sexp)
        values = @elements.values.map(&:to_sexp)

        elements = Hash[keys.zip(values)]

        [sexp_name, elements]
      end

      def to_a
        @elements.to_a
      end
    end

    class Set < Node
      def to_sexp
        [sexp_name,
          *@elements.map(&:to_sexp)]
      end
    end

    class Vector < Node
      def to_sexp
        [sexp_name,
          *@elements.map(&:to_sexp)]
      end
    end

    class Closure < Node
      include Scope

      attr_reader :arguments, :body

      def initialize(line, column, closure_arguments, body)
        @line = line
        @column = column
        @arguments = closure_arguments
        @body = body
      end
    end

    class ClosureArguments < Node
      attr_reader :arguments
      def initialize(line, column, vector)
        @line = line
        @column = column
        @arguments = vector.elements
        puts @arguments.inspect
      end

      def count
        @arguments.count
      end
    end

    class LetArguments < Node
      attr_reader :arguments, :values
      def initialize(line, column, vector)
        @line = line
        @column = column
        @bindings = vector.elements.each_slice(2)
        @arguments = @bindings.map(&:first)
        @values = @bindings.map(&:last)
      end

      def count
        @arguments.count
      end
    end

    class Receive < Node
      attr_reader :pattern, :actions

      def initialize(clauses)
        @pattern, *@actions = clauses
      end
    end

    class Match < Node
      include Scope

      class Pattern < Node

        def self.from(list)
          car, *cdr = list.elements
          case car
          when Number, String, Character, Keyword
            ValuePattern.new(car, cdr)
          when Symbol
            SymbolPattern.new(car, cdr)
          when Vector
            VectorPattern.new(car, cdr)
          else
            raise "Can't generate pattern from #{car.inspect}"
          end
        end

        attr_reader :value, :actions

        def initialize(value, actions=[])
          @value = value
          @actions = actions
        end

        def execute(compiler, success, g=compiler.g)
          actions.each do |action|
            action.accept(compiler)
          end
          g.goto success
        end
      end

      class ValuePattern < Pattern
        def match(compiler, failure, g=compiler.g)
          value.accept(compiler)
          g.swap_stack
          g.send :==, 1
          g.gif failure
        end
      end

      class SymbolPattern < Pattern
        def match(compiler, failure, g=compiler.g)
          # always matches
          unless value.name == :_
            local = g.state.scope.new_local(value.name)
            local.reference.set_bytecode(g)
          end
          g.pop
        end
      end

      class VectorPattern < Pattern
        def match(compiler, failure, g=compiler.g)
          # l = g.state.scope.search_local(:__value__)
          # l.get_bytecode(g)
          # g.inspect
          # g.pop

          match_length(g, failure)

          subpatterns.each_with_index do |pattern, idx|
            g.shift_array
            pattern.match(compiler, failure)
          end
        end

        private

        def subpatterns
          @subpatterns ||= value.elements.map { |x|
            l = List.new(value.line, value.column, x)
            Pattern.from(l)
          }
        end

        def match_length(g, failure)
          g.send :length, 0
          g.push value.elements.length
          g.send :==, 1
          g.gif failure
        end
      end

      attr_reader :expression, :patterns

      def initialize(line, column, patterns)
        @line = line
        @column = column
        @patterns = patterns.map { |list| Pattern.from(list) }
      end
    end
  end
end

RBX::AST::Node.send :include, Lambra::AST::Visitable
