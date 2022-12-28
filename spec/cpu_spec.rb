module Mos6510
  RSpec.describe Cpu do
    it 'can run a very simple example' do
      code = [
          *load_accumulator_with_constant(2),
          *add_constant_to_accumulator(5),
          *store_accumulator_at_address(4000),
          *return_from_subroutine
      ]
      cpu = Cpu.new(use_javascript_adapter: false)
      cpu.load(code, from: 1000)

      cpu.start
      cpu.jsr(1000)

      expect(cpu.peek(4000)).to eq(7)
    end

    it 'can do callbacks to SID object' do
      # The SID is mapped to the memory starting at position 54272
      code = [
          *load_accumulator_with_constant(117),
          *store_accumulator_at_address(54272 + 2),
          *return_from_subroutine
      ]
      sid = double('sid')
      cpu = Cpu.new(sid: sid, use_javascript_adapter: false)
      cpu.load(code, from: 1000)

      expect(sid).to receive(:poke).with(2, 117)

      cpu.start
      cpu.jsr(1000)
    end

    def load_accumulator_with_constant(value)
      [0xA9, value & 0xFF]
    end

    def add_constant_to_accumulator(value)
      [0x69, value & 0xFF]
    end

    def store_accumulator_at_address(address)
      [0x8D, address & 0xFF, (address >> 8) & 0xFF]
    end

    def return_from_subroutine
      [0x60]
    end
  end
end
