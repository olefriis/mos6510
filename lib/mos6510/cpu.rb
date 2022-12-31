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

    def inspect
      status = @cpu.p
      status_encoded = [
        (status & Mos6510::Flag::N) != 0, (status & Mos6510::Flag::V) != 0, (status & Mos6510::Flag::B2) != 0, (status & Mos6510::Flag::B1) != 0, (status & Mos6510::Flag::D) != 0,
        (status & Mos6510::Flag::I) != 0, (status & Mos6510::Flag::Z) != 0, (status & Mos6510::Flag::C) != 0
      ].reduce(0) { |acc, flag| (acc << 1) + (flag ? 1 : 0) }

      format(
        'a: 0x%02x, x: 0x%02x, y: 0x%02x, sp: 0x%02x, ' \
        'pc: 0x%04x, op: 0x%02x, status: 0b%08b, memory: %i',
        @cpu.a, @cpu.x, @cpu.y, @cpu.s, @cpu.pc, @cpu.getmem(@cpu.pc), status_encoded, @memory.sum
      )
    end

    def peek(address)
      @cpu.getmem(address)
    end
  end
end