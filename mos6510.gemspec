lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "mos6510/version"

Gem::Specification.new do |spec|
  spec.name          = 'mos6510'
  spec.version       = Mos6510::VERSION
  spec.authors       = ['Ole Friis Østergaard']
  spec.email         = ['olefriis@gmail.com']

  spec.summary       = 'MOS 6510 emulator'
  spec.description   = 'Emulate the CPU in the Commodore 64 and other classic home computers'
  spec.homepage      = 'https://github.com/olefriis/mos6510'
  spec.license       = 'GPL v2'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/olefriis/mos6510'
  spec.metadata['changelog_uri'] = 'https://github.com/olefriis/mos6510/CHANGELOG.md'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'mini_racer', '~> 0.3.1'
  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
end
