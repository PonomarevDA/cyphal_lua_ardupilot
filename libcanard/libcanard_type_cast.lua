function cast_float_to_int32(float)
  return string.unpack(">i4", string.pack(">f", float))
end

function cast_int32_to_float(int)
  return string.unpack(">f", string.pack(">i4", int))
end

function cast_native_float_to_float16(origin_native_float)
  local ROUND_MASK = 0xFFFFF000
  local MAGIC_FLOAT = cast_int32_to_float(15 << 23)

  local integer_representation = cast_float_to_int32(origin_native_float)
  integer_representation = integer_representation & ROUND_MASK
  local new_float = cast_int32_to_float(integer_representation) * MAGIC_FLOAT
  local new_float_int32 = cast_float_to_int32(new_float) + 4096
  local int16 = new_float_int32 >> 13

  return int16
end
