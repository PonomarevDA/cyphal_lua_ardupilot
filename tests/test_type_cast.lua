package.path = package.path .. ";libcanard/?.lua"
require 'libcanard_assert'
require 'libcanard_type_cast'

local function test_cast_native_float_to_float16()
  assert_eq(0, cast_native_float_to_float16(0.0))
  assert_eq(11878, cast_native_float_to_float16(0.1))
  assert_eq(15155, cast_native_float_to_float16(0.9))
  assert_eq(15360, cast_native_float_to_float16(1.0))
end

test_cast_native_float_to_float16()
