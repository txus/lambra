module Lambra
  module AST
    class Node
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

    class Form < Node
      def to_sexp
        [sexp_name, 
          *@elements.map(&:to_sexp)]
      end
    end
  end
end
