# This file is a pretty raw conversion of js/jssid.mos6510.js from
# https://github.com/jhohertz/jsSID

module Mos6510
	class Mos6510
		attr_accessor :cycles, :bval, :wval, :mem, :sid, :a, :x, :y, :s, :p, :pc

		def initialize(mem, sid: nil)
			# other internal values
			self.cycles = 0
			self.bval = 0
			self.wval = 0

			self.mem = mem
			self.sid = sid

			self.reset
		end

		def getmem(addr)
			#if (addr < 0 || addr > 65536) puts "jsSID.MOS6510.getmem: out of range addr: " + addr + " (caller: " + arguments.caller + ")"
			#if addr == 0xdd0d
			#	self.mem[addr] = 0;
			#}
			return self.mem[addr]
		end

		def setmem(addr, value)
			#if (addr < 0 || addr > 65535) puts "jsSID.MOS6510.getmem: out of range addr: " + addr + " (caller: " + arguments.caller + ")"
			#if (value < 0 || value > 255 ) puts "jsSID.MOS6510.getmem: out of range value: " + value + " (caller: " + arguments.caller + ")"
			if (addr & 0xfc00) == 0xd400 && self.sid
				self.sid.poke(addr & 0x1f, value)
				if addr > 0xd418
					puts "attempted digi poke:", addr, value
					self.sid.pokeDigi(addr, value)
				end
			else
				self.mem[addr] = value
			end
		end

		# just like pc++, but with bound check on pc after
		def pcinc
			pc = self.pc
			self.pc = (self.pc + 1) & 0xffff
			return pc
		end

		def getaddr(mode)
			case mode
			when Mode::IMP
				self.cycles += 2
				return 0
			when Mode::IMM
				self.cycles += 2
				return self.getmem(self.pcinc())
			when Mode::ABS
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad |= self.getmem(self.pcinc()) << 8
				return self.getmem(ad)
			when Mode::ABSX
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad |= 256 * self.getmem(self.pcinc())
				ad2 = ad + self.x
				ad2 &= 0xffff
				if (ad2 & 0xff00) != (ad & 0xff00)
					self.cycles += 1
				end
				return self.getmem(ad2)
			when Mode::ABSY
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad |= 256 * self.getmem(self.pcinc())
				ad2 = ad + self.y
				ad2 &= 0xffff
				if (ad2 & 0xff00) != (ad & 0xff00)
					self.cycles += 1
				end
				return self.getmem(ad2)
			when Mode::ZP
				self.cycles += 3
				ad = self.getmem(self.pcinc())
				return self.getmem(ad)
			when Mode::ZPX
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad += self.x
				return self.getmem(ad & 0xff)
			when Mode::ZPY
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad += self.y
				return self.getmem(ad & 0xff)
			when Mode::INDX
				self.cycles += 6
				ad = self.getmem(self.pcinc())
				ad += self.x
				ad2 = self.getmem(ad & 0xff)
				ad += 1
				ad2 |= self.getmem(ad & 0xff) << 8
				return self.getmem(ad2)
			when Mode::INDY
				self.cycles += 5
				ad = self.getmem(self.pcinc())
				ad2 = self.getmem(ad)
				ad2 |= self.getmem((ad + 1) & 0xff) << 8
				ad = ad2 + self.y
				ad &= 0xffff
				if (ad2 & 0xff00) != (ad & 0xff00)
					self.cycles += 1
				end
				return self.getmem(ad)
			when Mode::ACC
				self.cycles += 2
				return self.a
			end
			puts "getaddr: attempted unhandled mode"
			return 0
		end

		def setaddr(mode, val)
			# FIXME: not checking pc addresses as all should be relative to a valid instruction
			case mode
			when Mode::ABS
				self.cycles += 2
				ad = self.getmem(self.pc - 2)
				ad |= 256 * self.getmem(self.pc - 1)
				self.setmem(ad, val)
				return
			when Mode::ABSX
				self.cycles += 3
				ad = self.getmem(self.pc - 2)
				ad |= 256 * self.getmem(self.pc - 1)
				ad2 = ad + self.x
				ad2 &= 0xffff
				if (ad2 & 0xff00) != (ad & 0xff00)
					self.cycles -= 1
				end
				self.setmem(ad2, val)
				return
			when Mode::ZP
				self.cycles += 2
				ad = self.getmem(self.pc - 1)
				self.setmem(ad, val)
				return
			when Mode::ZPX
				self.cycles += 2
				ad = self.getmem(self.pc - 1)
				ad += self.x
				self.setmem(ad & 0xff, val)
				return
			when Mode::ACC
				self.a = val
				return
			end
			puts "setaddr: attempted unhandled mode"
		end

		def putaddr(mode, val)
			case mode
			when Mode::ABS
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad |= self.getmem(self.pcinc()) << 8
				self.setmem(ad, val)
				return
			when Mode::ABSX
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad |= self.getmem(self.pcinc()) << 8
				ad2 = ad + self.x
				ad2 &= 0xffff
				self.setmem(ad2, val)
				return
			when Mode::ABSY
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad |= self.getmem(self.pcinc()) << 8
				ad2 = ad + self.y
				ad2 &= 0xffff
				if (ad2 & 0xff00) != (ad & 0xff00)
					self.cycles += 1
				end
				self.setmem(ad2, val)
				return
			when Mode::ZP
				self.cycles += 3
				ad = self.getmem(self.pcinc())
				self.setmem(ad, val)
				return
			when Mode::ZPX
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad += self.x
				self.setmem(ad & 0xff, val)
				return
			when Mode::ZPY
				self.cycles += 4
				ad = self.getmem(self.pcinc())
				ad += self.y
				self.setmem(ad & 0xff,val)
				return
			when Mode::INDX
				self.cycles += 6
				ad = self.getmem(self.pcinc())
				ad += self.x
				ad2 = self.getmem(ad & 0xff)
				ad += 1
				ad2 |= self.getmem(ad & 0xff) << 8
				self.setmem(ad2, val)
				return
			when Mode::INDY
				self.cycles += 5
				ad = self.getmem(self.pcinc())
				ad2 = self.getmem(ad)
				ad2 |= self.getmem((ad + 1) & 0xff) << 8
				ad = ad2 + self.y
				ad &= 0xffff
				self.setmem(ad, val)
				return
			when Mode::ACC
				self.cycles += 2
				self.a = val
				return
			end
			puts "putaddr: attempted unhandled mode"
		end

		def setflags(flag, cond)
			if cond && cond != 0
				self.p |= flag
			else
				self.p &= ~flag & 0xff
			end
		end

		def push(val)
			self.setmem(0x100 + self.s, val)
			if self.s > 0
				self.s -= 1
			end
		end

		def pop
			if self.s < 0xff
				self.s += 1
			end
			self.getmem(0x100 + self.s)
		end

		def branch(flag)
			dist = self.getaddr(Mode::IMM)
			# FIXME: while this was checked out, it still seems too complicated
			# make signed
			if dist & 0x80 != 0
				dist = 0 - ((~dist & 0xff) + 1)
			end

			# this here needs to be extracted for general 16-bit rounding needs
			self.wval = self.pc + dist
			# FIXME: added boundary checks to wrap around. Not sure this is whats needed
			if self.wval < 0
				self.wval += 65536
			end
			self.wval &= 0xffff
			if flag
				self.cycles += ((self.pc & 0x100) != (self.wval & 0x100)) ? 2 : 1
				self.pc = self.wval
			end
		end

		def reset
			self.a	= 0
			self.x	= 0
			self.y	= 0
			self.p	= 0
			self.s	= 255
			self.pc	= self.getmem(0xfffc)
			self.pc |= 256 * self.getmem(0xfffd)
		end

		def step
			c = nil # Is this ever used?
			self.cycles = 0

			opc = self.getmem(self.pcinc())
			cmd = OPCODES[opc][0]
			addr = OPCODES[opc][1]

			case cmd
			when Inst::ADC
				self.wval = self.a + self.getaddr(addr) + ((self.p & Flag::C) != 0 ? 1 : 0)
				self.setflags(Flag::C, self.wval & 0x100)
				self.a = self.wval & 0xff
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
				self.setflags(Flag::V, ((self.p & Flag::C) != 0 ? 1 : 0) ^ ((self.p & Flag::N) != 0 ? 1 : 0))
			when Inst::AND
				self.bval = self.getaddr(addr)
				self.a &= self.bval
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
			when Inst::ASL
				self.wval = self.getaddr(addr)
				self.wval <<= 1
				self.setaddr(addr, self.wval & 0xff)
				self.setflags(Flag::Z, self.wval == 0)
				self.setflags(Flag::N, self.wval & 0x80)
				self.setflags(Flag::C, self.wval & 0x100)
			when Inst::BCC
				self.branch(!(self.p & Flag::C != 0))
			when Inst::BCS
				self.branch(self.p & Flag::C != 0)
			when Inst::BNE
				self.branch(!(self.p & Flag::Z != 0))
			when Inst::BEQ
				self.branch(self.p & Flag::Z != 0)
			when Inst::BPL
				self.branch(!(self.p & Flag::N != 0))
			when Inst::BMI
				self.branch(self.p & Flag::N != 0)
			when Inst::BVC
				self.branch(!(self.p & Flag::V != 0))
			when Inst::BVS
				self.branch(self.p & Flag::V != 0)
			when Inst::BIT
				self.bval = self.getaddr(addr)
				self.setflags(Flag::Z, (self.a & self.bval) == 0)
				self.setflags(Flag::N, self.bval & 0x80)
				self.setflags(Flag::V, self.bval & 0x40)
			when Inst::BRK
				pc = 0	# just quit per rockbox
				#self.push(self.pc & 0xff);
				#self.push(self.pc >> 8);
				#self.push(self.p);
				#self.setflags(jsSID.MOS6510.Flag::B, 1);
				# FIXME: should Z be set as well?
				#self.pc = self.getmem(0xfffe);
				#self.cycles += 7;
			when Inst::CLC
				self.cycles += 2
				self.setflags(Flag::C, 0)
			when Inst::CLD
				self.cycles += 2
				self.setflags(Flag::D, 0)
			when Inst::CLI
				self.cycles += 2
				self.setflags(Flag::I, 0)
			when Inst::CLV
				self.cycles += 2
				self.setflags(Flag::V, 0)
			when Inst::CMP
				self.bval = self.getaddr(addr)
				self.wval = self.a - self.bval
				# FIXME: may not actually be needed (yay 2's complement)
				if self.wval < 0
					self.wval += 256
				end
				self.setflags(Flag::Z, self.wval == 0)
				self.setflags(Flag::N, self.wval & 0x80)
				self.setflags(Flag::C, self.a >= self.bval)
			when Inst::CPX
				self.bval = self.getaddr(addr)
				self.wval = self.x - self.bval
				# FIXME: may not actually be needed (yay 2's complement)
				if self.wval < 0
					self.wval += 256
				end
				self.setflags(Flag::Z, self.wval == 0)
				self.setflags(Flag::N, self.wval & 0x80)
				self.setflags(Flag::C, self.x >= self.bval)
			when Inst::CPY
				self.bval = self.getaddr(addr)
				self.wval = self.y - self.bval
				# FIXME: may not actually be needed (yay 2's complement)
				if self.wval < 0
					self.wval += 256
				end
				self.setflags(Flag::Z, self.wval == 0)
				self.setflags(Flag::N, self.wval & 0x80)
				self.setflags(Flag::C, self.y >= self.bval)
			when Inst::DEC
				self.bval = self.getaddr(addr)
				self.bval -= 1
				# FIXME: may be able to just mask this (yay 2's complement)
				if self.bval < 0
					self.bval += 256
				end
				self.setaddr(addr, self.bval)
				self.setflags(Flag::Z, self.bval == 0)
				self.setflags(Flag::N, self.bval & 0x80)
			when Inst::DEX
				self.cycles += 2
				self.x -= 1
				# FIXME: may be able to just mask this (yay 2's complement)
				if self.x < 0
					self.x += 256
				end
				self.setflags(Flag::Z, self.x == 0)
				self.setflags(Flag::N, self.x & 0x80)
			when Inst::DEY
				self.cycles += 2
				self.y -= 1
				# FIXME: may be able to just mask this (yay 2's complement)
				if self.y < 0
					self.y += 256
				end
				self.setflags(Flag::Z, self.y == 0)
				self.setflags(Flag::N, self.y & 0x80)
			when Inst::EOR
				self.bval = self.getaddr(addr)
				self.a ^= self.bval
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
			when Inst::INC
				self.bval = self.getaddr(addr)
				self.bval += 1
				self.bval &= 0xff
				self.setaddr(addr, self.bval)
				self.setflags(Flag::Z, self.bval == 0)
				self.setflags(Flag::N, self.bval & 0x80)
			when Inst::INX
				self.cycles += 2
				self.x += 1
				self.x &= 0xff
				self.setflags(Flag::Z, self.x == 0)
				self.setflags(Flag::N, self.x & 0x80)
			when Inst::INY
				self.cycles += 2
				self.y += 1
				self.y &= 0xff
				self.setflags(Flag::Z, self.y == 0)
				self.setflags(Flag::N, self.y & 0x80)
			when Inst::JMP
				self.cycles += 3
				self.wval = self.getmem(self.pcinc())
				self.wval |= 256 * self.getmem(self.pcinc())
				case addr
				when Mode::ABS
					self.pc = self.wval
				when Mode::IND
					self.pc = self.getmem(self.wval)
					self.pc |= 256 * self.getmem((self.wval + 1) & 0xffff)
					self.cycles += 2
				end
			when Inst::JSR
				self.cycles += 6
				self.push(((self.pc + 1) & 0xffff) >> 8)
				self.push((self.pc + 1) & 0xff)
				self.wval = self.getmem(self.pcinc())
				self.wval |= 256 * self.getmem(self.pcinc())
				self.pc = self.wval
			when Inst::LDA
				self.a = self.getaddr(addr)
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
			when Inst::LDX
				self.x = self.getaddr(addr)
				self.setflags(Flag::Z, self.x == 0)
				self.setflags(Flag::N, self.x & 0x80)
			when Inst::LDY
				self.y = self.getaddr(addr)
				self.setflags(Flag::Z, self.y == 0)
				self.setflags(Flag::N, self.y & 0x80)
			when Inst::LSR
				self.bval = self.getaddr(addr)
				self.wval = self.bval
				self.wval >>= 1
				self.setaddr(addr, self.wval & 0xff)
				self.setflags(Flag::Z, self.wval == 0)
				self.setflags(Flag::N, self.wval & 0x80)
				self.setflags(Flag::C, self.bval & 1)
			when Inst::NOP
				self.cycles += 2
			when Inst::ORA
				self.bval = self.getaddr(addr)
				self.a |= self.bval
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
			when Inst::PHA
				self.push(self.a)
				self.cycles += 3
			when Inst::PHP
				self.push(self.p)
				self.cycles += 3
			when Inst::PLA
				self.a = self.pop
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
				self.cycles += 4
			when Inst::PLP
				self.p = self.pop
				self.cycles += 4
			when Inst::ROL
				self.bval = self.getaddr(addr)
				c = (self.p & Flag::C) != 0 ? 1 : 0
				self.setflags(Flag::C, self.bval & 0x80)
				self.bval <<= 1
				self.bval |= c
				self.bval &= 0xff
				self.setaddr(addr, self.bval)
				self.setflags(Flag::N, self.bval & 0x80)
				self.setflags(Flag::Z, self.bval == 0)
			when Inst::ROR
				self.bval = self.getaddr(addr)
				c = (self.p & Flag::C) != 0 ? 128 : 0
				self.setflags(Flag::C, self.bval & 1)
				self.bval >>= 1
				self.bval |= c
				self.setaddr(addr, self.bval)
				self.setflags(Flag::N, self.bval & 0x80)
				self.setflags(Flag::Z, self.bval == 0)
			when Inst::RTI
				# treat like RTS
			when Inst::RTS
				self.wval = self.pop
				self.wval |= 256 * self.pop
				self.pc = self.wval + 1
				self.cycles += 6
			when Inst::SBC
				self.bval = self.getaddr(addr) ^ 0xff
				self.wval = self.a + self.bval + ((self.p & Flag::C) != 0 ? 1 : 0)
				self.setflags(Flag::C, self.wval & 0x100)
				self.a = self.wval & 0xff
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a > 127)
				self.setflags(Flag::V, ((self.p & Flag::C) != 0 ? 1 : 0) ^ ((self.p & Flag::N) != 0 ? 1 : 0))
			when Inst::SEC
				self.cycles += 2
				self.setflags(Flag::C, 1)
			when Inst::SED
				self.cycles += 2
				self.setflags(Flag::D, 1)
			when Inst::SEI
				self.cycles += 2
				self.setflags(Flag::I, 1)
			when Inst::STA
				self.putaddr(addr, self.a)
			when Inst::STX
				self.putaddr(addr, self.x)
			when Inst::STY
				self.putaddr(addr, self.y)
			when Inst::TAX
				self.cycles += 2
				self.x = self.a
				self.setflags(Flag::Z, self.x == 0)
				self.setflags(Flag::N, self.x & 0x80)
			when Inst::TAY
				self.cycles += 2
				self.y = self.a
				self.setflags(Flag::Z, self.y == 0)
				self.setflags(Flag::N, self.y & 0x80)
			when Inst::TSX
				self.cycles += 2
				self.x = self.s
				self.setflags(Flag::Z, self.x == 0)
				self.setflags(Flag::N, self.x & 0x80)
			when Inst::TXA
				self.cycles += 2
				self.a = self.x
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
			when Inst::TXS
				self.cycles += 2
				self.s = self.x
			when Inst::TYA
				self.cycles += 2
				self.a = self.y
				self.setflags(Flag::Z, self.a == 0)
				self.setflags(Flag::N, self.a & 0x80)
			else
				puts "step: attempted unhandled instruction, opcode: #{opc}"
			end

			self.cycles
		end

		def jsr(npc, na)
			ccl = 0

			self.a = na
			self.x = 0
			self.y = 0
			self.p = 0
			self.s = 255
			self.pc = npc
			self.push(0)
			self.push(0)

			while self.pc > 1
				ccl += self.step
			end

			ccl
		end

		# Flags Enum
		module Flag
			N = 128; V = 64; B = 16; D = 8; I = 4; Z = 2; C = 1
		end

		# Opcodes Enum
		module Inst
			ADC = 'adc'; AND = 'and'; ASL = 'asl'; BCC = 'bcc'; BCS = 'bcs'; BEQ = 'beq'; BIT = 'bit'; BMI = 'bmi'; BNE = 'bne'; BPL = 'bpl'; BRK = 'brk'; BVC = 'bvc'; BVS = 'bvs'; CLC = 'clc';
			CLD = 'cld'; CLI = 'cli'; CLV = 'clv'; CMP = 'cmp'; CPX = 'cpx'; CPY = 'cpy'; DEC = 'dec'; DEX = 'dex'; DEY = 'dey'; EOR = 'eor'; INC = 'inc'; INX = 'inx'; INY = 'iny'; JMP = 'jmp';
			JSR = 'jsr'; LDA = 'lda'; LDX = 'ldx'; LDY = 'ldy'; LSR = 'lsr'; NOP = 'nop'; ORA = 'ora'; PHA = 'pha'; PHP = 'php'; PLA = 'pla'; PLP = 'plp'; ROL = 'rol'; ROR = 'ror'; RTI = 'rti';
			RTS = 'rts'; SBC = 'sbc'; SEC = 'sec'; SED = 'sed'; SEI = 'sei'; STA = 'sta'; STX = 'stx'; STY = 'sty'; TAX = 'tax'; TAY = 'tay'; TSX = 'tsx'; TXA = 'txa'; TXS = 'txs'; TYA = 'tya';
			XXX = 'xxx'
		end

		# Modes Enum
		module Mode
			IMP = 'imp'; IMM = 'imm'; ABS = 'abs'; ABSX = 'absx'; ABSY = 'absy'; ZP = 'zp'; ZPX = 'zpx'; ZPY = 'zpy'; IND = 'ind'; INDX = 'indx'; INDY = 'indy'; ACC = 'acc'; REL = 'rel'; XXX = 'xxx'
		end

		# 256 entries, each entry array pair of [inst, mode]
		OPCODES = [
			[Inst::BRK, Mode::IMP],							# 0x00
			[Inst::ORA, Mode::INDX],							# 0x01
			[Inst::XXX, Mode::XXX],							# 0x02
			[Inst::XXX, Mode::XXX],							# 0x03
			[Inst::XXX, Mode::ZP],							# 0x04
			[Inst::ORA, Mode::ZP],							# 0x05
			[Inst::ASL, Mode::ZP],							# 0x06
			[Inst::XXX, Mode::XXX],							# 0x07
			[Inst::PHP, Mode::IMP],							# 0x08
			[Inst::ORA, Mode::IMM],							# 0x09
			[Inst::ASL, Mode::ACC],							# 0x0a
			[Inst::XXX, Mode::XXX],							# 0x0b
			[Inst::XXX, Mode::ABS],							# 0x0c
			[Inst::ORA, Mode::ABS],							# 0x0d
			[Inst::ASL, Mode::ABS],							# 0x0e
			[Inst::XXX, Mode::XXX],							# 0x0f

			[Inst::BPL, Mode::REL],							# 0x10
			[Inst::ORA, Mode::INDY],							# 0x11
			[Inst::XXX, Mode::XXX],							# 0x12
			[Inst::XXX, Mode::XXX],							# 0x13
			[Inst::XXX, Mode::XXX],							# 0x14
			[Inst::ORA, Mode::ZPX],							# 0x15
			[Inst::ASL, Mode::ZPX],							# 0x16
			[Inst::XXX, Mode::XXX],							# 0x17
			[Inst::CLC, Mode::IMP],							# 0x18
			[Inst::ORA, Mode::ABSY],							# 0x19
			[Inst::XXX, Mode::XXX],							# 0x1a
			[Inst::XXX, Mode::XXX],							# 0x1b
			[Inst::XXX, Mode::XXX],							# 0x1c
			[Inst::ORA, Mode::ABSX],							# 0x1d
			[Inst::ASL, Mode::ABSX],							# 0x1e
			[Inst::XXX, Mode::XXX],							# 0x1f

			[Inst::JSR, Mode::ABS],							# 0x20
			[Inst::AND, Mode::INDX],							# 0x21
			[Inst::XXX, Mode::XXX],							# 0x22
			[Inst::XXX, Mode::XXX],							# 0x23
			[Inst::BIT, Mode::ZP],							# 0x24
			[Inst::AND, Mode::ZP],							# 0x25
			[Inst::ROL, Mode::ZP],							# 0x26
			[Inst::XXX, Mode::XXX],							# 0x27
			[Inst::PLP, Mode::IMP],							# 0x28
			[Inst::AND, Mode::IMM],							# 0x29
			[Inst::ROL, Mode::ACC],							# 0x2a
			[Inst::XXX, Mode::XXX],							# 0x2b
			[Inst::BIT, Mode::ABS],							# 0x2c
			[Inst::AND, Mode::ABS],							# 0x2d
			[Inst::ROL, Mode::ABS],							# 0x2e
			[Inst::XXX, Mode::XXX],							# 0x2f

			[Inst::BMI, Mode::REL],							# 0x30
			[Inst::AND, Mode::INDY],							# 0x31
			[Inst::XXX, Mode::XXX],							# 0x32
			[Inst::XXX, Mode::XXX],							# 0x33
			[Inst::XXX, Mode::XXX],							# 0x34
			[Inst::AND, Mode::ZPX],							# 0x35
			[Inst::ROL, Mode::ZPX],							# 0x36
			[Inst::XXX, Mode::XXX],							# 0x37
			[Inst::SEC, Mode::IMP],							# 0x38
			[Inst::AND, Mode::ABSY],							# 0x39
			[Inst::XXX, Mode::XXX],							# 0x3a
			[Inst::XXX, Mode::XXX],							# 0x3b
			[Inst::XXX, Mode::XXX],							# 0x3c
			[Inst::AND, Mode::ABSX],							# 0x3d
			[Inst::ROL, Mode::ABSX],							# 0x3e
			[Inst::XXX, Mode::XXX],							# 0x3f

			[Inst::RTI, Mode::IMP],							# 0x40
			[Inst::EOR, Mode::INDX],							# 0x41
			[Inst::XXX, Mode::XXX],							# 0x42
			[Inst::XXX, Mode::XXX],							# 0x43
			[Inst::XXX, Mode::ZP],							# 0x44
			[Inst::EOR, Mode::ZP],							# 0x45
			[Inst::LSR, Mode::ZP],							# 0x46
			[Inst::XXX, Mode::XXX],							# 0x47
			[Inst::PHA, Mode::IMP],							# 0x48
			[Inst::EOR, Mode::IMM],							# 0x49
			[Inst::LSR, Mode::ACC],							# 0x4a
			[Inst::XXX, Mode::XXX],							# 0x4b
			[Inst::JMP, Mode::ABS],							# 0x4c
			[Inst::EOR, Mode::ABS],							# 0x4d
			[Inst::LSR, Mode::ABS],							# 0x4e
			[Inst::XXX, Mode::XXX],							# 0x4f

			[Inst::BVC, Mode::REL],							# 0x50
			[Inst::EOR, Mode::INDY],							# 0x51
			[Inst::XXX, Mode::XXX],							# 0x52
			[Inst::XXX, Mode::XXX],							# 0x53
			[Inst::XXX, Mode::XXX],							# 0x54
			[Inst::EOR, Mode::ZPX],							# 0x55
			[Inst::LSR, Mode::ZPX],							# 0x56
			[Inst::XXX, Mode::XXX],							# 0x57
			[Inst::CLI, Mode::IMP],							# 0x58
			[Inst::EOR, Mode::ABSY],							# 0x59
			[Inst::XXX, Mode::XXX],							# 0x5a
			[Inst::XXX, Mode::XXX],							# 0x5b
			[Inst::XXX, Mode::XXX],							# 0x5c
			[Inst::EOR, Mode::ABSX],							# 0x5d
			[Inst::LSR, Mode::ABSX],							# 0x5e
			[Inst::XXX, Mode::XXX],							# 0x5f

			[Inst::RTS, Mode::IMP],							# 0x60
			[Inst::ADC, Mode::INDX],							# 0x61
			[Inst::XXX, Mode::XXX],							# 0x62
			[Inst::XXX, Mode::XXX],							# 0x63
			[Inst::XXX, Mode::ZP],							# 0x64
			[Inst::ADC, Mode::ZP],							# 0x65
			[Inst::ROR, Mode::ZP],							# 0x66
			[Inst::XXX, Mode::XXX],							# 0x67
			[Inst::PLA, Mode::IMP],							# 0x68
			[Inst::ADC, Mode::IMM],							# 0x69
			[Inst::ROR, Mode::ACC],							# 0x6a
			[Inst::XXX, Mode::XXX],							# 0x6b
			[Inst::JMP, Mode::IND],							# 0x6c
			[Inst::ADC, Mode::ABS],							# 0x6d
			[Inst::ROR, Mode::ABS],							# 0x6e
			[Inst::XXX, Mode::XXX],							# 0x6f

			[Inst::BVS, Mode::REL],							# 0x70
			[Inst::ADC, Mode::INDY],							# 0x71
			[Inst::XXX, Mode::XXX],							# 0x72
			[Inst::XXX, Mode::XXX],							# 0x73
			[Inst::XXX, Mode::XXX],							# 0x74
			[Inst::ADC, Mode::ZPX],							# 0x75
			[Inst::ROR, Mode::ZPX],							# 0x76
			[Inst::XXX, Mode::XXX],							# 0x77
			[Inst::SEI, Mode::IMP],							# 0x78
			[Inst::ADC, Mode::ABSY],							# 0x79
			[Inst::XXX, Mode::XXX],							# 0x7a
			[Inst::XXX, Mode::XXX],							# 0x7b
			[Inst::XXX, Mode::XXX],							# 0x7c
			[Inst::ADC, Mode::ABSX],							# 0x7d
			[Inst::ROR, Mode::ABSX],							# 0x7e
			[Inst::XXX, Mode::XXX],							# 0x7f

			[Inst::XXX, Mode::IMM],							# 0x80
			[Inst::STA, Mode::INDX],							# 0x81
			[Inst::XXX, Mode::XXX],							# 0x82
			[Inst::XXX, Mode::XXX],							# 0x83
			[Inst::STY, Mode::ZP],							# 0x84
			[Inst::STA, Mode::ZP],							# 0x85
			[Inst::STX, Mode::ZP],							# 0x86
			[Inst::XXX, Mode::XXX],							# 0x87
			[Inst::DEY, Mode::IMP],							# 0x88
			[Inst::XXX, Mode::IMM],							# 0x89
			[Inst::TXA, Mode::ACC],							# 0x8a
			[Inst::XXX, Mode::XXX],							# 0x8b
			[Inst::STY, Mode::ABS],							# 0x8c
			[Inst::STA, Mode::ABS],							# 0x8d
			[Inst::STX, Mode::ABS],							# 0x8e
			[Inst::XXX, Mode::XXX],							# 0x8f

			[Inst::BCC, Mode::REL],							# 0x90
			[Inst::STA, Mode::INDY],							# 0x91
			[Inst::XXX, Mode::XXX],							# 0x92
			[Inst::XXX, Mode::XXX],							# 0x93
			[Inst::STY, Mode::ZPX],							# 0x94
			[Inst::STA, Mode::ZPX],							# 0x95
			[Inst::STX, Mode::ZPY],							# 0x96
			[Inst::XXX, Mode::XXX],							# 0x97
			[Inst::TYA, Mode::IMP],							# 0x98
			[Inst::STA, Mode::ABSY],							# 0x99
			[Inst::TXS, Mode::ACC],							# 0x9a
			[Inst::XXX, Mode::XXX],							# 0x9b
			[Inst::XXX, Mode::XXX],							# 0x9c
			[Inst::STA, Mode::ABSX],							# 0x9d
			[Inst::XXX, Mode::ABSX],							# 0x9e
			[Inst::XXX, Mode::XXX],							# 0x9f

			[Inst::LDY, Mode::IMM],							# 0xa0
			[Inst::LDA, Mode::INDX],							# 0xa1
			[Inst::LDX, Mode::IMM],							# 0xa2
			[Inst::XXX, Mode::XXX],							# 0xa3
			[Inst::LDY, Mode::ZP],							# 0xa4
			[Inst::LDA, Mode::ZP],							# 0xa5
			[Inst::LDX, Mode::ZP],							# 0xa6
			[Inst::XXX, Mode::XXX],							# 0xa7
			[Inst::TAY, Mode::IMP],							# 0xa8
			[Inst::LDA, Mode::IMM],							# 0xa9
			[Inst::TAX, Mode::ACC],							# 0xaa
			[Inst::XXX, Mode::XXX],							# 0xab
			[Inst::LDY, Mode::ABS],							# 0xac
			[Inst::LDA, Mode::ABS],							# 0xad
			[Inst::LDX, Mode::ABS],							# 0xae
			[Inst::XXX, Mode::XXX],							# 0xaf

			[Inst::BCS, Mode::REL],							# 0xb0
			[Inst::LDA, Mode::INDY],							# 0xb1
			[Inst::XXX, Mode::XXX],							# 0xb2
			[Inst::XXX, Mode::XXX],							# 0xb3
			[Inst::LDY, Mode::ZPX],							# 0xb4
			[Inst::LDA, Mode::ZPX],							# 0xb5
			[Inst::LDX, Mode::ZPY],							# 0xb6
			[Inst::XXX, Mode::XXX],							# 0xb7
			[Inst::CLV, Mode::IMP],							# 0xb8
			[Inst::LDA, Mode::ABSY],							# 0xb9
			[Inst::TSX, Mode::ACC],							# 0xba
			[Inst::XXX, Mode::XXX],							# 0xbb
			[Inst::LDY, Mode::ABSX],							# 0xbc
			[Inst::LDA, Mode::ABSX],							# 0xbd
			[Inst::LDX, Mode::ABSY],							# 0xbe
			[Inst::XXX, Mode::XXX],							# 0xbf

			[Inst::CPY, Mode::IMM],							# 0xc0
			[Inst::CMP, Mode::INDX],							# 0xc1
			[Inst::XXX, Mode::XXX],							# 0xc2
			[Inst::XXX, Mode::XXX],							# 0xc3
			[Inst::CPY, Mode::ZP],							# 0xc4
			[Inst::CMP, Mode::ZP],							# 0xc5
			[Inst::DEC, Mode::ZP],							# 0xc6
			[Inst::XXX, Mode::XXX],							# 0xc7
			[Inst::INY, Mode::IMP],							# 0xc8
			[Inst::CMP, Mode::IMM],							# 0xc9
			[Inst::DEX, Mode::ACC],							# 0xca
			[Inst::XXX, Mode::XXX],							# 0xcb
			[Inst::CPY, Mode::ABS],							# 0xcc
			[Inst::CMP, Mode::ABS],							# 0xcd
			[Inst::DEC, Mode::ABS],							# 0xce
			[Inst::XXX, Mode::XXX],							# 0xcf

			[Inst::BNE, Mode::REL],							# 0xd0
			[Inst::CMP, Mode::INDY],							# 0xd1
			[Inst::XXX, Mode::XXX],							# 0xd2
			[Inst::XXX, Mode::XXX],							# 0xd3
			[Inst::XXX, Mode::ZPX],							# 0xd4
			[Inst::CMP, Mode::ZPX],							# 0xd5
			[Inst::DEC, Mode::ZPX],							# 0xd6
			[Inst::XXX, Mode::XXX],							# 0xd7
			[Inst::CLD, Mode::IMP],							# 0xd8
			[Inst::CMP, Mode::ABSY],							# 0xd9
			[Inst::XXX, Mode::ACC],							# 0xda
			[Inst::XXX, Mode::XXX],							# 0xdb
			[Inst::XXX, Mode::XXX],							# 0xdc
			[Inst::CMP, Mode::ABSX],							# 0xdd
			[Inst::DEC, Mode::ABSX],							# 0xde
			[Inst::XXX, Mode::XXX],							# 0xdf

			[Inst::CPX, Mode::IMM],							# 0xe0
			[Inst::SBC, Mode::INDX],							# 0xe1
			[Inst::XXX, Mode::XXX],							# 0xe2
			[Inst::XXX, Mode::XXX],							# 0xe3
			[Inst::CPX, Mode::ZP],							# 0xe4
			[Inst::SBC, Mode::ZP],							# 0xe5
			[Inst::INC, Mode::ZP],							# 0xe6
			[Inst::XXX, Mode::XXX],							# 0xe7
			[Inst::INX, Mode::IMP],							# 0xe8
			[Inst::SBC, Mode::IMM],							# 0xe9
			[Inst::NOP, Mode::ACC],							# 0xea
			[Inst::XXX, Mode::XXX],							# 0xeb
			[Inst::CPX, Mode::ABS],							# 0xec
			[Inst::SBC, Mode::ABS],							# 0xed
			[Inst::INC, Mode::ABS],							# 0xee
			[Inst::XXX, Mode::XXX],							# 0xef

			[Inst::BEQ, Mode::REL],							# 0xf0
			[Inst::SBC, Mode::INDY],							# 0xf1
			[Inst::XXX, Mode::XXX],							# 0xf2
			[Inst::XXX, Mode::XXX],							# 0xf3
			[Inst::XXX, Mode::ZPX],							# 0xf4
			[Inst::SBC, Mode::ZPX],							# 0xf5
			[Inst::INC, Mode::ZPX],							# 0xf6
			[Inst::XXX, Mode::XXX],							# 0xf7
			[Inst::SED, Mode::IMP],							# 0xf8
			[Inst::SBC, Mode::ABSY],							# 0xf9
			[Inst::XXX, Mode::ACC],							# 0xfa
			[Inst::XXX, Mode::XXX],							# 0xfb
			[Inst::XXX, Mode::XXX],							# 0xfc
			[Inst::SBC, Mode::ABSX],							# 0xfd
			[Inst::INC, Mode::ABSX],							# 0xfe
			[Inst::XXX, Mode::XXX]							# 0xff
		].freeze
	end
end