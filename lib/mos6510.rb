require 'mos6510/version'

module Mos6510
  class Error < StandardError; end

  require 'mos6510/cpu'
  require 'mos6510/jssid_mos6510'
end
