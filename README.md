# MOS 6510

A Ruby gem emulating the MOS 6510 microprocessor found in the Commodore 64. The processor
has the same instruction set as the MOS6502 which is found in other entertainment systems.

Additionally, the gem allows you to supply an object which simulates the SID processor
(Sound Interface Device - the sound chip from the Commodore 64). This object will receive
`poke` calls whenever the simulated program writes to the addresses mapped to the SID.

Be warned: This is just a very raw conversion of a JavaScript implementation stolen (*)
from the [jsSID](https://github.com/jhohertz/jsSID) project. It has bugs, probably
because of my conversion. I'd love fix this one day, but just needed a MOS 6510 emulator
for another project.

(*) This explains the GPL v2 license of this project.

## Usage

```ruby
require 'mos6510'

class MySid
  def poke(address, value)
    puts "SID address #{address} set to value #{value}"
  end
end

instructions = [
  # MOS 6510 instructions as an array of bytes
]

# If you don't want to simulate a SID, just leave that out
cpu = Mos6510::Cpu.new(sid: sid)
# Read the instructions in the memory, starting at location 500
cpu.load(instructions, from: 500)
cpu.start

# Jump to address 500, and hope that your program will return sometime
cpu.jsr(500)

# If your program left a result in the memory, look at the contents of an address
puts "Memory address 1300 contains #{cpu.peek(1300)}"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec`
to run the tests. You can also run `bin/console` for an interactive prompt that will allow
you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a
new version, update the version number in `version.rb`, and then run `bundle exec rake release`,
which will create a git tag for the version, push git commits and tags, and push the `.gem`
file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/olefriis/mos6510.

## License

The gem is available as open source under the terms of the
[GPL V2 License](https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
