module Lambra
  module AST
    module Scope
      attr_accessor :parent

      def self.included(base)
        base.send :include, Rubinius::Compiler::LocalVariables
      end

      def nest_scope(scope)
        scope.parent = self
      end

      # A nested scope is looking up a local variable. If the variable exists
      # in our local variables hash, return a nested reference to it. If it
      # exists in an enclosing scope, increment the depth of the reference
      # when it passes through this nested scope (i.e. the depth of a
      # reference is a function of the nested scopes it passes through from
      # the scope it is defined in to the scope it is used in).
      def search_local(name)
        if variable = variables[name]
          variable.nested_reference
        elsif block_local?(name)
          new_local name
        elsif reference = @parent.search_local(name)
          reference.depth += 1
          reference
        end
      end

      def block_local?(name)
        @locals.include?(name) if @locals
      end

      def new_local(name)
        variable = Rubinius::Compiler::LocalVariable.new allocate_slot
        variables[name] = variable
      end

      def new_nested_local(name)
        new_local(name).nested_reference
      end

      # If the local variable exists in this scope, set the local variable
      # node attribute to a reference to the local variable. If the variable
      # exists in an enclosing scope, set the local variable node attribute to
      # a nested reference to the local variable. Otherwise, create a local
      # variable in this scope and set the local variable node attribute.
      def assign_local_reference(var)
        if variable = variables[var.name]
          var.variable = variable.reference
        elsif block_local?(var.name)
          variable = new_local var.name
          var.variable = variable.reference
        elsif reference = @parent.search_local(var.name)
          reference.depth += 1
          var.variable = reference
        else
          variable = new_local var.name
          var.variable = variable.reference
        end
      end
    end

    module Visitable
      def accept(visitor)
        name = self.class.name.split("::").last
        visitor.send "visit_#{name}", self
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
        @elements.map(&:to_sexp)
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
      end

      def count
        @arguments.count
      end
    end
  end
end
