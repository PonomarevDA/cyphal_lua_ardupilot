require 'libcanard_crc16'
require 'libcanard_assert'

local function test_crc16()
  assert_eq(62800, crc16_add_byte(0xFFFF, 0xAA))
  assert_eq(34620, crc16_add_byte(62800, 0x42))

  local byte_array = {0xAA, 0x42}
  assert_eq(34620, calc_crc16(byte_array, 2))
end

test_crc16()
