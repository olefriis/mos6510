module Mos6510
  class Cpu
    def initialize(sid: nil)
      @memory = [0] * 65536
      @sid = sid
    end

    def load(bytes, from: 0)
      bytes.each_with_index do |byte, index|
        @memory[from + index] = byte
      end
    end

    def start
      @cpu = Mos6510.new(@memory, sid: @sid)
    end

    def jsr(address, accumulator_value=0)
      @cpu.jsr(address, accumulator_value)
    end

    def step
      @cpu.step
    end

    def pc
      @cpu.pc
    end

    def pc=(new_pc)
      @cpu.pc = new_pc
    end

    def peek(address)
      @cpu.getmem(address)
    end
  end
end