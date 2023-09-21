require 'libcanard_type_cast'
require 'libcanard_crc16'

function array_serialize(setpoints, motors_amount, payload)
  payload[1] = motors_amount

  for motor_num = 1, motors_amount do
    setpoint = setpoints[motor_num]
    if (setpoint ~= nil) then
      payload[motor_num << 1] = setpoint % 256
      payload[(motor_num << 1) + 1] = (setpoint >> 8) % 256
    end
  end

  return 1 + 2 * motors_amount
end

function vector_serialize(setpoints, motors_amount, payload)
  for motor_idx = 0, motors_amount - 1 do
    setpoint_f16 = cast_native_float_to_float16(setpoints[motor_idx + 1])
    if (setpoint_f16 ~= nil) then
      payload[(motor_idx << 1) + 1] = setpoint_f16 % 256
      payload[(motor_idx << 1) + 2] = (setpoint_f16 >> 8) % 256
    end
  end

  return motors_amount * 2
end

local function compact_feedback_deserialize_voltage(payload)
  return (payload[1] + ((payload[2] % 8) << 8))
end

local function compact_feedback_deserialize_dc_current(payload)
  return ((payload[2] >> 3) + ((payload[3] % 128) << 5))
end

local function compact_feedback_deserialize_rpm(payload)
  return ((payload[5] >> 3) + (payload[6] << 5))
end

function compact_feedback_deserialize(payload, payload_size)
  -- uint11 dc_voltage # [    0,+2047] * 0.2 = [     0,+409.4] volt
  -- int12 dc_current  # [-2048,+2047] * 0.2 = [-409.6,+409.4] ampere
  -- int13 velocity    # [-4096,+4095] radian/second (approx. [-39114,+39104] RPM)
  local feedback = {}

  if payload_size == 7 then
    feedback.voltage = compact_feedback_deserialize_voltage(payload)
    feedback.dc_current = compact_feedback_deserialize_dc_current(payload)
    feedback.rpm = compact_feedback_deserialize_rpm(payload)
  end

  return feedback
end
