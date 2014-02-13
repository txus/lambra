require 'thread'

module Lambra
  class Message
    attr_reader :contents
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
      x = Thread.new {
        begin
          process = new(&fn)
          register(process)
          process.call
        ensure
          unregister(process)
        end
      }.object_id
      sleep 0.01 # FIXME
      x
    end

    def self.current
      self[Thread.current.object_id]
    end

    def self.register(process)
      pid = Thread.current.object_id
      self[pid] = process
      Thread.current[:process] = process
    end

    def self.unregister(process)
      @processes.delete(Thread.current.object_id)
      Thread.current.delete(:process)
    end

    def initialize(&fn)
      @mailbox = Queue.new
      @fn = fn
    end

    def call
      @fn.call
    end

    def pid
      Thread.current.object_id
    end

    def push(*args)
      @mailbox.push(Message.new(*args))
    end

    def pop
      @mailbox.pop
    end
  end
end
