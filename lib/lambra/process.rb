require 'thread'

module Lambra
  class Message
    def initialize(*args)
      @contents = args
    end
  end

  class Process
    @processes = {}

    def self.pids
      @processes.keys
    end

    def self.[](pid)
      @processes[pid]
    end

    def self.[]=(pid, process)
      @processes[pid] = process
    end

    def self.count
      @processes.count
    end

    def self.spawn(&fn)
      Thread.new {
        new(&fn).tap { |process|
          pid = Thread.current.object_id
          self[pid] = process
          Thread.current[:process] = process
        }.call
      }.object_id
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
