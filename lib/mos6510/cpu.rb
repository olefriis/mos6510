require 'mini_racer'

module Mos6510
  class Cpu
    def initialize(sid: nil)
      @context = MiniRacer::Context.new

      # Just define the name space used by the main mos6510 emulator
      @context.eval 'function jsSID() {}'

      @context.load(File.join(__dir__, 'jssid.mos6510.js'))

      @context.eval <<~EOS
        var memory = new Array(65536);
		    for(var i=0; i<65536; i++) {
			    memory[i]=0;
		    }
        var sid = null;
      EOS

      if sid
        @context.attach("sidPoke", proc{ |address, value| sid.poke(address, value) })
        @context.eval <<~EOS
          sid = {
            poke: function(address, value) { sidPoke(address, value); }
          };
        EOS
      end
    end

    def load(bytes, from: 0)
      bytes.each_with_index do |byte, index|
        @context.eval "memory[#{from + index}] = #{byte};"
      end
    end

    def start
      @context.eval <<~EOS
        var cpu = new jsSID.MOS6510(memory, sid);
      EOS
    end

    def jsr(address, accumulator_value=0)
      @context.eval "cpu.cpuJSR(#{address}, #{accumulator_value});"
    end

    def peek(address)
      @context.eval "cpu.mem[#{address}]"
    end
  end
end