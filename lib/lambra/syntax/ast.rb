require_relative 'scope'

module Lambra
  module AST
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
      end

      def count
        @arguments.count
      end
    end
  end
end
