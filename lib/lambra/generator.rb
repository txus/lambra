module Lambra
  class Generator < RBX::Generator
    def push_process
      push_cpath_top
      find_const :Lambra
      find_const :Process
      send :current, 0
    end

    def inspect
      dup_top
      push_self
      swap_stack
      send :inspect, 0
      send :puts, 1, true
      pop
    end
  end
end
