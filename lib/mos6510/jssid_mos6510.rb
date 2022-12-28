
class Mos6510
	attr_accessor :cycles, :bval, :wval, :mem, :sid, :x, :y, :s, :p

	def initialize(mem, sid: nil)
		# other internal values
		self.cycles = 0
		self.bval = 0
		self.wval = 0

		self.mem = mem || [0] * 65536
		self.sid = sid

		self.cpuReset()
	end

	def getmem(addr)
		#if (addr < 0 || addr > 65536) puts "jsSID.MOS6510.getmem: out of range addr: " + addr + " (caller: " + arguments.caller + ")"
		#if addr == 0xdd0d
		#	self.mem[addr] = 0;
		#}
		return self.mem[addr]
	};

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
			self.mem[addr] = value;
		end
	end

	# just like pc++, but with bound check on pc after
	def pcinc(mode)
		pc = self.pc
		self.pc = (self.pc + 1) & 0xffff
		return pc
	end

	def getaddr(mode)
		ad, ad2 = nil
		case mode
		when mode.imp
			self.cycles += 2
			return 0
		when mode.imm
			self.cycles += 2
			return self.getmem(self.pcinc())
		when mode.abs
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad |= self.getmem(self.pcinc()) << 8
			return self.getmem(ad)
		when mode.absx
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad |= 256 * self.getmem(self.pcinc())
			ad2 = ad + self.x
			ad2 &= 0xffff
			if (ad2 & 0xff00) != (ad & 0xff00)
				self.cycles += 1
			end
			return self.getmem(ad2)
		when mode.absy
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad |= 256 * self.getmem(self.pcinc())
			ad2 = ad + self.y
			ad2 &= 0xffff
			if (ad2 & 0xff00) != (ad & 0xff00)
				self.cycles += 1
			end
			return self.getmem(ad2)
		when mode.zp
			self.cycles += 3
			ad = self.getmem(self.pcinc())
			return self.getmem(ad)
		when mode.zpx
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad += self.x
			return self.getmem(ad & 0xff)
		when mode.zpy
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad += self.y
			return self.getmem(ad & 0xff)
		when mode.indx
			self.cycles += 6
			ad = self.getmem(self.pcinc())
			ad += self.x
			ad2 = self.getmem(ad & 0xff)
			ad += 1
			ad2 |= self.getmem(ad & 0xff) << 8
			return self.getmem(ad2)
		when mode.indy
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
		when mode.acc
			self.cycles += 2
			return self.a
		end
		puts "getaddr: attempted unhandled mode"
		return 0
	end

	def setaddr(mode, val)
		ad, ad2 = nil
		# FIXME: not checking pc addresses as all should be relative to a valid instruction
		case mode
		when mode.abs
			self.cycles += 2
			ad = self.getmem(self.pc - 2)
			ad |= 256 * self.getmem(self.pc - 1)
			self.setmem(ad, val)
			return
		when mode.absx
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
		when mode.zp
			self.cycles += 2
			ad = self.getmem(self.pc - 1)
			self.setmem(ad, val)
			return
		when mode.zpx
			self.cycles += 2
			ad = self.getmem(self.pc - 1)
			ad += self.x
			self.setmem(ad & 0xff, val)
			return
		when mode.acc
			self.a = val
			return
		end
		puts "setaddr: attempted unhandled mode"
	end

	def putaddr(mode, val)
		ad, ad2 = nil
		case mode
		when mode.abs
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad |= self.getmem(self.pcinc()) << 8
			self.setmem(ad, val)
			return
		when mode.absx
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad |= self.getmem(self.pcinc()) << 8
			ad2 = ad + self.x
			ad2 &= 0xffff
			self.setmem(ad2, val)
			return
		when mode.absy
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
		when mode.zp
			self.cycles += 3
			ad = self.getmem(self.pcinc())
			self.setmem(ad, val)
			return
		when mode.zpx
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad += self.x
			self.setmem(ad & 0xff, val)
			return
		when mode.zpy
			self.cycles += 4
			ad = self.getmem(self.pcinc())
			ad += self.y
			self.setmem(ad & 0xff,val)
			return;
		when mode.indx
			self.cycles += 6
			ad = self.getmem(self.pcinc())
			ad += self.x
			ad2 = self.getmem(ad & 0xff)
			ad++
			ad2 |= self.getmem(ad & 0xff) << 8
			self.setmem(ad2, val)
			return
		when mode.indy
			self.cycles += 5
			ad = self.getmem(self.pcinc())
			ad2 = self.getmem(ad)
			ad2 |= self.getmem((ad + 1) & 0xff) << 8
			ad = ad2 + self.y
			ad &= 0xffff
			self.setmem(ad, val)
			return
		when mode.acc
			self.cycles += 2
			self.a = val
			return
		end
		puts "putaddr: attempted unhandled mode"
	end

	def setflags(flag, cond)
		if cond
			self.p |= flag;
		else
			self.p &= ~flag & 0xff;
		end
	end

	def push(val)
		self.setmem(0x100 + self.s, val)
		if (self.s)
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
		var dist = self.getaddr(mode.imm)
		# FIXME: while this was checked out, it still seems too complicated
		# make signed
		if dist & 0x80
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

	def cpuReset
		self.a	= 0
		self.x	= 0
		self.y	= 0
		self.p	= 0
		self.s	= 255
		self.pc	= self.getmem(0xfffc)
		self.pc |= 256 * self.getmem(0xfffd)
	end

	def cpuResetTo(npc, na)
		self.a	= na || 0
		self.x	= 0
		self.y	= 0
		self.p	= 0
		self.s	= 255
		self.pc	= npc
	end

	def cpuParse
		c = nil # Is this ever used?
		self.cycles = 0

		opc = self.getmem(self.pcinc())
		cmd = opcodes[opc][0]
		addr = opcodes[opc][1]

		case cmd
		when inst.adc
			self.wval = self.a + self.getaddr(addr) + ((self.p & flag.C) ? 1 : 0)
			self.setflags(flag.C, self.wval & 0x100)
			self.a = self.wval & 0xff
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a & 0x80)
			self.setflags(flag.V, ((self.p & flag.C) ? 1 : 0) ^ ((self.p & flag.N) ? 1 : 0))
		when inst.and
			self.bval = self.getaddr(addr)
			self.a &= self.bval
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a & 0x80)
		when inst.asl
			self.wval = self.getaddr(addr)
			self.wval <<= 1
			self.setaddr(addr, self.wval & 0xff)
			self.setflags(flag.Z, !self.wval)
			self.setflags(flag.N, self.wval & 0x80)
			self.setflags(flag.C, self.wval & 0x100)
		when inst.bcc
			self.branch(!(self.p & flag.C))
		when inst.bcs
			self.branch(self.p & flag.C)
		when inst.bne
			self.branch(!(self.p & flag.Z))
		when inst.beq
			self.branch(self.p & flag.Z)
		when inst.bpl
			self.branch(!(self.p & flag.N))
		when inst.bmi
			self.branch(self.p & flag.N)
		when inst.bvc
			self.branch(!(self.p & flag.V))
		when inst.bvs
			self.branch(self.p & flag.V)
		when inst.bit
			self.bval = self.getaddr(addr)
			self.setflags(flag.Z, !(self.a & self.bval))
			self.setflags(flag.N, self.bval & 0x80)
			self.setflags(flag.V, self.bval & 0x40)
		when inst.brk
			pc = 0	# just quit per rockbox
			#self.push(self.pc & 0xff);
			#self.push(self.pc >> 8);
			#self.push(self.p);
			#self.setflags(jsSID.MOS6510.flag.B, 1);
			# FIXME: should Z be set as well?
			#self.pc = self.getmem(0xfffe);
			#self.cycles += 7;
		when inst.clc
			self.cycles += 2
			self.setflags(flag.C, 0)
		when inst.cld
			self.cycles += 2
			self.setflags(flag.D, 0)
		when inst.cli
			self.cycles += 2
			self.setflags(flag.I, 0)
		when inst.clv
			self.cycles += 2
			self.setflags(flag.V, 0)
		when inst.cmp
			self.bval = self.getaddr(addr)
			self.wval = self.a - self.bval
			# FIXME: may not actually be needed (yay 2's complement)
			if self.wval < 0
				self.wval += 256
			end
			self.setflags(flag.Z, !self.wval)
			self.setflags(flag.N, self.wval & 0x80)
			self.setflags(flag.C, self.a >= self.bval)
		when inst.cpx
			self.bval = self.getaddr(addr)
			self.wval = self.x - self.bval
			# FIXME: may not actually be needed (yay 2's complement)
			if self.wval < 0
				self.wval += 256
			end
			self.setflags(flag.Z, !self.wval)
			self.setflags(flag.N, self.wval & 0x80)
			self.setflags(flag.C, self.x >= self.bval)
		when inst.cpy
			self.bval = self.getaddr(addr)
			self.wval = self.y - self.bval
			# FIXME: may not actually be needed (yay 2's complement)
			if self.wval < 0
				self.wval += 256
			end
			self.setflags(flag.Z, !self.wval)
			self.setflags(flag.N, self.wval & 0x80)
			self.setflags(flag.C, self.y >= self.bval)
		when inst.dec
			self.bval = self.getaddr(addr)
			self.bval -= 1
			# FIXME: may be able to just mask this (yay 2's complement)
			if self.bval < 0
				self.bval += 256
			end
			self.setaddr(addr, self.bval)
			self.setflags(flag.Z, !self.bval)
			self.setflags(flag.N, self.bval & 0x80)
		when inst.dex
			self.cycles += 2
			self.x -= 1
			# FIXME: may be able to just mask this (yay 2's complement)
			if self.x < 0
				self.x += 256
			end
			self.setflags(flag.Z, !self.x)
			self.setflags(flag.N, self.x & 0x80)
		when inst.dey
			self.cycles += 2
			self.y -= 1
			# FIXME: may be able to just mask this (yay 2's complement)
			if self.y < 0
				self.y += 256
			end
			self.setflags(flag.Z, !self.y)
			self.setflags(flag.N, self.y & 0x80)
		when inst.eor
			self.bval = self.getaddr(addr)
			self.a ^= self.bval
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a & 0x80)
		when inst.inc
			self.bval = self.getaddr(addr)
			self.bval += 1
			self.bval &= 0xff
			self.setaddr(addr, self.bval)
			self.setflags(flag.Z, !self.bval)
			self.setflags(flag.N, self.bval & 0x80)
		when inst.inx
			self.cycles += 2
			self.x += 1
			self.x &= 0xff
			self.setflags(flag.Z, !self.x)
			self.setflags(flag.N, self.x & 0x80)
		when inst.iny
			self.cycles += 2
			self.y += 1
			self.y &= 0xff
			self.setflags(flag.Z, !self.y)
			self.setflags(flag.N, self.y & 0x80)
		when inst.jmp
			self.cycles += 3
			self.wval = self.getmem(self.pcinc())
			self.wval |= 256 * self.getmem(self.pcinc())
			case addr
			when mode.abs
				self.pc = self.wval
			when mode.ind
				self.pc = self.getmem(self.wval)
				self.pc |= 256 * self.getmem((self.wval + 1) & 0xffff)
				self.cycles += 2
			end
		when inst.jsr
			self.cycles += 6
			self.push(((self.pc + 1) & 0xffff) >> 8)
			self.push((self.pc + 1) & 0xff)
			self.wval = self.getmem(self.pcinc())
			self.wval |= 256 * self.getmem(self.pcinc())
			self.pc = self.wval
		when inst.lda
			self.a = self.getaddr(addr)
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a & 0x80)
		when inst.ldx
			self.x = self.getaddr(addr)
			self.setflags(flag.Z, !self.x)
			self.setflags(flag.N, self.x & 0x80)
		when inst.ldy
			self.y = self.getaddr(addr)
			self.setflags(flag.Z, !self.y)
			self.setflags(flag.N, self.y & 0x80)
		when inst.lsr
			self.bval = self.getaddr(addr)
			self.wval = self.bval
			self.wval >>= 1
			self.setaddr(addr, self.wval & 0xff)
			self.setflags(flag.Z, !self.wval)
			self.setflags(flag.N, self.wval & 0x80)
			self.setflags(flag.C, self.bval & 1)
		when inst.nop
			self.cycles += 2
		when inst.ora
			self.bval = self.getaddr(addr)
			self.a |= self.bval
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a & 0x80)
		when inst.pha
			self.push(self.a)
			self.cycles += 3
		when inst.php
			self.push(self.p)
			self.cycles += 3
		when inst.pla
			self.a = self.pop
			self.setflags(Z, !self.a)
			self.setflags(N, self.a & 0x80)
			self.cycles += 4
		when inst.plp
			self.p = self.pop
			self.cycles += 4
		when inst.rol
			self.bval = self.getaddr(addr)
			c = (self.p & flag.C) ? 1 : 0
			self.setflags(flag.C, self.bval & 0x80)
			self.bval <<= 1
			self.bval |= c
			self.bval &= 0xff
			self.setaddr(addr, self.bval)
			self.setflags(flag.N, self.bval & 0x80)
			self.setflags(flag.Z, !self.bval)
		when inst.ror
			self.bval = self.getaddr(addr)
			c = (self.p & flag.C) ? 128 : 0
			self.setflags(flag.C, self.bval & 1)
			self.bval >>= 1
			self.bval |= c
			self.setaddr(addr, self.bval)
			self.setflags(flag.N, self.bval & 0x80)
			self.setflags(flag.Z, !self.bval)
		when inst.rti
			# treat like RTS
		when inst.rts
			self.wval = self.pop
			self.wval |= 256 * self.pop
			self.pc = self.wval + 1
			self.cycles += 6
		when inst.sbc
			self.bval = self.getaddr(addr) ^ 0xff
			self.wval = self.a + self.bval + (( self.p & jsSID.MOS6510.flag.C) ? 1 : 0)
			self.setflags(flag.C, self.wval & 0x100)
			self.a = self.wval & 0xff
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a > 127)
			self.setflags(flag.V, ((self.p & flag.C) ? 1 : 0) ^ ((self.p & flag.N) ? 1 : 0))
		when inst.sec
			self.cycles += 2
			self.setflags(flag.C, 1)
		when inst.sed
			self.cycles += 2
			self.setflags(flag.D, 1)
		when inst.sei
			self.cycles += 2
			self.setflags(flag.I, 1)
		when inst.sta
			self.putaddr(addr, self.a)
		when inst.stx
			self.putaddr(addr, self.x)
		when inst.sty
			self.putaddr(addr, self.y)
		when inst.tax
			self.cycles += 2
			self.x = self.a
			self.setflags(flag.Z, !self.x)
			self.setflags(flag.N, self.x & 0x80)
		when inst.tay
			self.cycles += 2
			self.y = self.a
			self.setflags(flag.Z, !self.y)
			self.setflags(flag.N, self.y & 0x80)
		when inst.tsx
			self.cycles += 2
			self.x = self.s
			self.setflags(flag.Z, !self.x)
			self.setflags(flag.N, self.x & 0x80)
		when inst.txa
			self.cycles += 2
			self.a = self.x
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a & 0x80)
		when inst.txs
			self.cycles += 2
			self.s = self.x
		when inst.tya
			self.cycles += 2
			self.a = self.y
			self.setflags(flag.Z, !self.a)
			self.setflags(flag.N, self.a & 0x80)
		else
			puts "cpuParse: attempted unhandled instruction, opcode: #{opc}"
		end

		self.cycles
	end

	def cpuJSR(npc, na)
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
			ccl += self.cpuParse()
		end

		ccl
	end

	# Flags Enum
	flag = {
		N: 128, V: 64, B: 16, D: 8, I: 4, Z: 2, C: 1
	}.freeze

	# Opcodes Enum
	inst = {
		adc: {}, and: {}, asl: {}, bcc: {}, bcs: {}, beq: {}, bit: {}, bmi: {}, bne: {}, bpl: {}, brk: {}, bvc: {}, bvs: {}, clc: {},
		cld: {}, cli: {}, clv: {}, cmp: {}, cpx: {}, cpy: {}, dec: {}, dex: {}, dey: {}, eor: {}, inc: {}, inx: {}, iny: {}, jmp: {},
		jsr: {}, lda: {}, ldx: {}, ldy: {}, lsr: {}, nop: {}, ora: {}, pha: {}, php: {}, pla: {}, plp: {}, rol: {}, ror: {}, rti: {},
		rts: {}, sbc: {}, sec: {}, sed: {}, sei: {}, sta: {}, stx: {}, sty: {}, tax: {}, tay: {}, tsx: {}, txa: {}, txs: {}, tya: {},
		xxx: {}
	}.freeze

	# Modes Enum
	mode = {
		imp: {}, imm: {}, abs: {}, absx: {}, absy: {}, zp: {}, zpx: {}, zpy: {}, ind: {}, indx: {}, indy: {}, acc: {}, rel: {}, xxx: {}
	}.freeze

	# 256 entries, each entry array pair of [inst, mode]
	opcodes = [
		[inst.brk, mode.imp],							# 0x00
		[inst.ora, mode.indx],							# 0x01
		[inst.xxx, mode.xxx],							# 0x02
		[inst.xxx, mode.xxx],							# 0x03
		[inst.xxx, mode.zp],							# 0x04
		[inst.ora, mode.zp],							# 0x05
		[inst.asl, mode.zp],							# 0x06
		[inst.xxx, mode.xxx],							# 0x07
		[inst.php, mode.imp],							# 0x08
		[inst.ora, mode.imm],							# 0x09
		[inst.asl, mode.acc],							# 0x0a
		[inst.xxx, mode.xxx],							# 0x0b
		[inst.xxx, mode.abs],							# 0x0c
		[inst.ora, mode.abs],							# 0x0d
		[inst.asl, mode.abs],							# 0x0e
		[inst.xxx, mode.xxx],							# 0x0f

		[inst.bpl, mode.rel],							# 0x10
		[inst.ora, mode.indy],							# 0x11
		[inst.xxx, mode.xxx],							# 0x12
		[inst.xxx, mode.xxx],							# 0x13
		[inst.xxx, mode.xxx],							# 0x14
		[inst.ora, mode.zpx],							# 0x15
		[inst.asl, mode.zpx],							# 0x16
		[inst.xxx, mode.xxx],							# 0x17
		[inst.clc, mode.imp],							# 0x18
		[inst.ora, mode.absy],							# 0x19
		[inst.xxx, mode.xxx],							# 0x1a
		[inst.xxx, mode.xxx],							# 0x1b
		[inst.xxx, mode.xxx],							# 0x1c
		[inst.ora, mode.absx],							# 0x1d
		[inst.asl, mode.absx],							# 0x1e
		[inst.xxx, mode.xxx],							# 0x1f

		[inst.jsr, mode.abs],							# 0x20
		[inst.and, mode.indx],							# 0x21
		[inst.xxx, mode.xxx],							# 0x22
		[inst.xxx, mode.xxx],							# 0x23
		[inst.bit, mode.zp],							# 0x24
		[inst.and, mode.zp],							# 0x25
		[inst.rol, mode.zp],							# 0x26
		[inst.xxx, mode.xxx],							# 0x27
		[inst.plp, mode.imp],							# 0x28
		[inst.and, mode.imm],							# 0x29
		[inst.rol, mode.acc],							# 0x2a
		[inst.xxx, mode.xxx],							# 0x2b
		[inst.bit, mode.abs],							# 0x2c
		[inst.and, mode.abs],							# 0x2d
		[inst.rol, mode.abs],							# 0x2e
		[inst.xxx, mode.xxx],							# 0x2f

		[inst.bmi, mode.rel],							# 0x30
		[inst.and, mode.indy],							# 0x31
		[inst.xxx, mode.xxx],							# 0x32
		[inst.xxx, mode.xxx],							# 0x33
		[inst.xxx, mode.xxx],							# 0x34
		[inst.and, mode.zpx],							# 0x35
		[inst.rol, mode.zpx],							# 0x36
		[inst.xxx, mode.xxx],							# 0x37
		[inst.sec, mode.imp],							# 0x38
		[inst.and, mode.absy],							# 0x39
		[inst.xxx, mode.xxx],							# 0x3a
		[inst.xxx, mode.xxx],							# 0x3b
		[inst.xxx, mode.xxx],							# 0x3c
		[inst.and, mode.absx],							# 0x3d
		[inst.rol, mode.absx],							# 0x3e
		[inst.xxx, mode.xxx],							# 0x3f

		[inst.rti, mode.imp],							# 0x40
		[inst.eor, mode.indx],							# 0x41
		[inst.xxx, mode.xxx],							# 0x42
		[inst.xxx, mode.xxx],							# 0x43
		[inst.xxx, mode.zp],							# 0x44
		[inst.eor, mode.zp],							# 0x45
		[inst.lsr, mode.zp],							# 0x46
		[inst.xxx, mode.xxx],							# 0x47
		[inst.pha, mode.imp],							# 0x48
		[inst.eor, mode.imm],							# 0x49
		[inst.lsr, mode.acc],							# 0x4a
		[inst.xxx, mode.xxx],							# 0x4b
		[inst.jmp, mode.abs],							# 0x4c
		[inst.eor, mode.abs],							# 0x4d
		[inst.lsr, mode.abs],							# 0x4e
		[inst.xxx, mode.xxx],							# 0x4f

		[inst.bvc, mode.rel],							# 0x50
		[inst.eor, mode.indy],							# 0x51
		[inst.xxx, mode.xxx],							# 0x52
		[inst.xxx, mode.xxx],							# 0x53
		[inst.xxx, mode.xxx],							# 0x54
		[inst.eor, mode.zpx],							# 0x55
		[inst.lsr, mode.zpx],							# 0x56
		[inst.xxx, mode.xxx],							# 0x57
		[inst.cli, mode.imp],							# 0x58
		[inst.eor, mode.absy],							# 0x59
		[inst.xxx, mode.xxx],							# 0x5a
		[inst.xxx, mode.xxx],							# 0x5b
		[inst.xxx, mode.xxx],							# 0x5c
		[inst.eor, mode.absx],							# 0x5d
		[inst.lsr, mode.absx],							# 0x5e
		[inst.xxx, mode.xxx],							# 0x5f

		[inst.rts, mode.imp],							# 0x60
		[inst.adc, mode.indx],							# 0x61
		[inst.xxx, mode.xxx],							# 0x62
		[inst.xxx, mode.xxx],							# 0x63
		[inst.xxx, mode.zp],							# 0x64
		[inst.adc, mode.zp],							# 0x65
		[inst.ror, mode.zp],							# 0x66
		[inst.xxx, mode.xxx],							# 0x67
		[inst.pla, mode.imp],							# 0x68
		[inst.adc, mode.imm],							# 0x69
		[inst.ror, mode.acc],							# 0x6a
		[inst.xxx, mode.xxx],							# 0x6b
		[inst.jmp, mode.ind],							# 0x6c
		[inst.adc, mode.abs],							# 0x6d
		[inst.ror, mode.abs],							# 0x6e
		[inst.xxx, mode.xxx],							# 0x6f

		[inst.bvs, mode.rel],							# 0x70
		[inst.adc, mode.indy],							# 0x71
		[inst.xxx, mode.xxx],							# 0x72
		[inst.xxx, mode.xxx],							# 0x73
		[inst.xxx, mode.xxx],							# 0x74
		[inst.adc, mode.zpx],							# 0x75
		[inst.ror, mode.zpx],							# 0x76
		[inst.xxx, mode.xxx],							# 0x77
		[inst.sei, mode.imp],							# 0x78
		[inst.adc, mode.absy],							# 0x79
		[inst.xxx, mode.xxx],							# 0x7a
		[inst.xxx, mode.xxx],							# 0x7b
		[inst.xxx, mode.xxx],							# 0x7c
		[inst.adc, mode.absx],							# 0x7d
		[inst.ror, mode.absx],							# 0x7e
		[inst.xxx, mode.xxx],							# 0x7f

		[inst.xxx, mode.imm],							# 0x80
		[inst.sta, mode.indx],							# 0x81
		[inst.xxx, mode.xxx],							# 0x82
		[inst.xxx, mode.xxx],							# 0x83
		[inst.sty, mode.zp],							# 0x84
		[inst.sta, mode.zp],							# 0x85
		[inst.stx, mode.zp],							# 0x86
		[inst.xxx, mode.xxx],							# 0x87
		[inst.dey, mode.imp],							# 0x88
		[inst.xxx, mode.imm],							# 0x89
		[inst.txa, mode.acc],							# 0x8a
		[inst.xxx, mode.xxx],							# 0x8b
		[inst.sty, mode.abs],							# 0x8c
		[inst.sta, mode.abs],							# 0x8d
		[inst.stx, mode.abs],							# 0x8e
		[inst.xxx, mode.xxx],							# 0x8f

		[inst.bcc, mode.rel],							# 0x90
		[inst.sta, mode.indy],							# 0x91
		[inst.xxx, mode.xxx],							# 0x92
		[inst.xxx, mode.xxx],							# 0x93
		[inst.sty, mode.zpx],							# 0x94
		[inst.sta, mode.zpx],							# 0x95
		[inst.stx, mode.zpy],							# 0x96
		[inst.xxx, mode.xxx],							# 0x97
		[inst.tya, mode.imp],							# 0x98
		[inst.sta, mode.absy],							# 0x99
		[inst.txs, mode.acc],							# 0x9a
		[inst.xxx, mode.xxx],							# 0x9b
		[inst.xxx, mode.xxx],							# 0x9c
		[inst.sta, mode.absx],							# 0x9d
		[inst.xxx, mode.absx],							# 0x9e
		[inst.xxx, mode.xxx],							# 0x9f

		[inst.ldy, mode.imm],							# 0xa0
		[inst.lda, mode.indx],							# 0xa1
		[inst.ldx, mode.imm],							# 0xa2
		[inst.xxx, mode.xxx],							# 0xa3
		[inst.ldy, mode.zp],							# 0xa4
		[inst.lda, mode.zp],							# 0xa5
		[inst.ldx, mode.zp],							# 0xa6
		[inst.xxx, mode.xxx],							# 0xa7
		[inst.tay, mode.imp],							# 0xa8
		[inst.lda, mode.imm],							# 0xa9
		[inst.tax, mode.acc],							# 0xaa
		[inst.xxx, mode.xxx],							# 0xab
		[inst.ldy, mode.abs],							# 0xac
		[inst.lda, mode.abs],							# 0xad
		[inst.ldx, mode.abs],							# 0xae
		[inst.xxx, mode.xxx],							# 0xaf

		[inst.bcs, mode.rel],							# 0xb0
		[inst.lda, mode.indy],							# 0xb1
		[inst.xxx, mode.xxx],							# 0xb2
		[inst.xxx, mode.xxx],							# 0xb3
		[inst.ldy, mode.zpx],							# 0xb4
		[inst.lda, mode.zpx],							# 0xb5
		[inst.ldx, mode.zpy],							# 0xb6
		[inst.xxx, mode.xxx],							# 0xb7
		[inst.clv, mode.imp],							# 0xb8
		[inst.lda, mode.absy],							# 0xb9
		[inst.tsx, mode.acc],							# 0xba
		[inst.xxx, mode.xxx],							# 0xbb
		[inst.ldy, mode.absx],							# 0xbc
		[inst.lda, mode.absx],							# 0xbd
		[inst.ldx, mode.absy],							# 0xbe
		[inst.xxx, mode.xxx],							# 0xbf

		[inst.cpy, mode.imm],							# 0xc0
		[inst.cmp, mode.indx],							# 0xc1
		[inst.xxx, mode.xxx],							# 0xc2
		[inst.xxx, mode.xxx],							# 0xc3
		[inst.cpy, mode.zp],							# 0xc4
		[inst.cmp, mode.zp],							# 0xc5
		[inst.dec, mode.zp],							# 0xc6
		[inst.xxx, mode.xxx],							# 0xc7
		[inst.iny, mode.imp],							# 0xc8
		[inst.cmp, mode.imm],							# 0xc9
		[inst.dex, mode.acc],							# 0xca
		[inst.xxx, mode.xxx],							# 0xcb
		[inst.cpy, mode.abs],							# 0xcc
		[inst.cmp, mode.abs],							# 0xcd
		[inst.dec, mode.abs],							# 0xce
		[inst.xxx, mode.xxx],							# 0xcf

		[inst.bne, mode.rel],							# 0xd0
		[inst.cmp, mode.indy],							# 0xd1
		[inst.xxx, mode.xxx],							# 0xd2
		[inst.xxx, mode.xxx],							# 0xd3
		[inst.xxx, mode.zpx],							# 0xd4
		[inst.cmp, mode.zpx],							# 0xd5
		[inst.dec, mode.zpx],							# 0xd6
		[inst.xxx, mode.xxx],							# 0xd7
		[inst.cld, mode.imp],							# 0xd8
		[inst.cmp, mode.absy],							# 0xd9
		[inst.xxx, mode.acc],							# 0xda
		[inst.xxx, mode.xxx],							# 0xdb
		[inst.xxx, mode.xxx],							# 0xdc
		[inst.cmp, mode.absx],							# 0xdd
		[inst.dec, mode.absx],							# 0xde
		[inst.xxx, mode.xxx],							# 0xdf

		[inst.cpx, mode.imm],							# 0xe0
		[inst.sbc, mode.indx],							# 0xe1
		[inst.xxx, mode.xxx],							# 0xe2
		[inst.xxx, mode.xxx],							# 0xe3
		[inst.cpx, mode.zp],							# 0xe4
		[inst.sbc, mode.zp],							# 0xe5
		[inst.inc, mode.zp],							# 0xe6
		[inst.xxx, mode.xxx],							# 0xe7
		[inst.inx, mode.imp],							# 0xe8
		[inst.sbc, mode.imm],							# 0xe9
		[inst.nop, mode.acc],							# 0xea
		[inst.xxx, mode.xxx],							# 0xeb
		[inst.cpx, mode.abs],							# 0xec
		[inst.sbc, mode.abs],							# 0xed
		[inst.inc, mode.abs],							# 0xee
		[inst.xxx, mode.xxx],							# 0xef

		[inst.beq, mode.rel],							# 0xf0
		[inst.sbc, mode.indy],							# 0xf1
		[inst.xxx, mode.xxx],							# 0xf2
		[inst.xxx, mode.xxx],							# 0xf3
		[inst.xxx, mode.zpx],							# 0xf4
		[inst.sbc, mode.zpx],							# 0xf5
		[inst.inc, mode.zpx],							# 0xf6
		[inst.xxx, mode.xxx],							# 0xf7
		[inst.sed, mode.imp],							# 0xf8
		[inst.sbc, mode.absy],							# 0xf9
		[inst.xxx, mode.acc],							# 0xfa
		[inst.xxx, mode.xxx],							# 0xfb
		[inst.xxx, mode.xxx],							# 0xfc
		[inst.sbc, mode.absx],							# 0xfd
		[inst.inc, mode.absx],							# 0xfe
		[inst.xxx, mode.xxx]							# 0xff
	].freeze
end