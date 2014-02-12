require 'thread'

module Lambra
  class Message
    def initialize(*args)
      @contents = args
    end
  end

  class Process
    @processes = {}

    def self.[](pid)
      @processes[pid]
    end

    def self.[]=(pid, process)
      @processes[pid] = process
    end

    def self.spawn(&fn)
      Thread.new do
        new(&fn).tap { |process|
          self[Thread.current.object_id] = process
          Thread.current[:process] = process
        }.call
      end
    end

    def initialize(&fn)
      @mailbox = Queue.new
      @fn = fn
    end

    def call
      @fn.call
    end

    def push(*args)
      @mailbox.push(Message.new(*args))
    end

    def pop
      @mailbox.pop
    end
  end
end
