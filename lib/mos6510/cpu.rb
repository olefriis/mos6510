require 'mini_racer'

module Mos6510
  class Cpu
    attr_reader :use_javascript_adapter

    def initialize(sid: nil, use_javascript_adapter: true)
      @use_javascript_adapter = use_javascript_adapter

      if use_javascript_adapter
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
          @context.attach("sidPoke", proc { |address, value| sid.poke(address, value) })
          @context.eval <<~EOS
            sid = {
              poke: function(address, value) { sidPoke(address, value); }
            };
          EOS
        end
      else
        @memory = [0] * 65536
        @sid = sid
      end
    end

    def load(bytes, from: 0)
      if use_javascript_adapter
        bytes.each_with_index do |byte, index|
          @context.eval "memory[#{from + index}] = #{byte};"
        end
      else
        bytes.each_with_index do |byte, index|
          @memory[from + index] = byte
        end
      end
    end

    def start
      if use_javascript_adapter
        @context.eval <<~EOS
          var cpu = new jsSID.MOS6510(memory, sid);
        EOS
      else
        @cpu = Mos6510.new(@memory, sid: @sid)
      end
    end

    def jsr(address, accumulator_value=0)
      if use_javascript_adapter
        @context.eval "cpu.cpuJSR(#{address}, #{accumulator_value});"
      else
        @cpu.cpuJSR(address, accumulator_value)
      end
    end

    def peek(address)
      if use_javascript_adapter
        @context.eval "cpu.mem[#{address}]"
      else
        @cpu.getmem(address)
      end
    end
  end
end