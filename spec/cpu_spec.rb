module Mos6510
  RSpec.describe Cpu do
    it 'can run a very simple example' do
      code = [
          *load_accumulator_with_constant(2),
          *add_constant_to_accumulator(5),
          *store_accumulator_at_address(4000),
          *return_from_subroutine
      ]
      cpu = Cpu.new
      cpu.load(code, from: 1000)

      cpu.start
      cpu.jsr(1000)

      expect(cpu.peek(4000)).to eq(7)
    end

    it "can run the whole Klaus Dormann functional test suite" do#, skip: "Needs more work!" do
      # TODO: This suite does _not_ pass currently. It relies on you copying
      # bin_files/6502_functional_test.bin from https://github.com/Klaus2m5/6502_65C02_functional_tests
      # (and even then, it ends up on the wrong PC)
      image = File.read(File.join(__dir__, '6502_functional_test.bin')).bytes
      cpu = Cpu.new
      cpu.load(image)
      cpu.start
      cpu.pc = 0x400

      last_pc = 0
      while last_pc != cpu.pc
        last_pc = cpu.pc
        puts cpu.inspect

        #puts "Stepping: #{last_pc}"
        cpu.step
      end

      expect(last_pc).to eq(0x3469)
    end

    it 'can do callbacks to SID object' do
      # The SID is mapped to the memory starting at position 54272
      code = [
          *load_accumulator_with_constant(117),
          *store_accumulator_at_address(54272 + 2),
          *return_from_subroutine
      ]
      sid = double('sid')
      cpu = Cpu.new(sid: sid)
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
