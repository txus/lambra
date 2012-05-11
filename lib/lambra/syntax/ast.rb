module Lambra
  module AST
    class Node
      attr_reader :line, :column

      def sexp_name
        self.class.name.split('::').last.downcase.to_sym
      end

      def to_sexp
        [sexp_name]
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
    end

    class Vector < Node
      def to_sexp
        [sexp_name, 
          *@elements.map(&:to_sexp)]
      end
    end
  end
end
