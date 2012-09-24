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
  end
end
