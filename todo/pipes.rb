require 'mutex'
module Gtk2GO
  class Pipes
    def initialize
      @pipes = []
      @all = []
      @mutex = Mutex.new
    end

    def shift
      pipe = nil
      while pipe == nil do
        Thread.pass
        @mutex.synchronize do
          pipe = @pipes.shift
        end
      end
      return pipe
    end

    def push(pipe)
      @mutex.synchronize do
        @pipes.push(pipe)
      end
    end

    def add(command)
      pipe = IO.popen(command,'w+')
      @all.push(pipe)
      self.push(pipe)
    end

    def close
      @all.each{|pipe| pipe.close}
    end
  end
end
