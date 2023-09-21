-- Cyphal
local driver1 = CAN:get_device(20)
assert(driver1 ~= nil, 'No scripting CAN interfaces found')

local PARAM_TABLE_KEY = 42
assert(param:add_table(PARAM_TABLE_KEY, "CYP_", 6), 'could not add param table')
assert(param:add_param(PARAM_TABLE_KEY, 1, 'ENABLE', 1), 'could not add CYP_ENABLE param')
assert(param:add_param(PARAM_TABLE_KEY, 2, 'NODE_ID', 127), 'could not add CYP_NODE_ID param')
assert(param:add_param(PARAM_TABLE_KEY, 3, 'TESTS', 0), 'could not add CYP_TESTS param')
assert(param:add_param(PARAM_TABLE_KEY, 4, 'SP', 65535), 'could not add CYP_SP param')
assert(param:add_param(PARAM_TABLE_KEY, 5, 'RD', 65535), 'could not add CYP_RD param')
assert(param:add_param(PARAM_TABLE_KEY, 6, 'FB', 65535), 'could not add CYP_FB param')

local param_cyp_enable = Parameter("CYP_ENABLE")  -- 1 = enabled, 0 = disabled
local param_cyp_tests = Parameter("CYP_TESTS")    -- 1 = enabled, 0 = disabled
local node_id = Parameter("CYP_NODE_ID"):get()

local HEARTBEAT_PORT_ID = 7509
local heartbeat_transfer_id = 0
local next_heartbeat_pub_time_ms = 1000

local readiness_port_id = Parameter("CYP_RD"):get()
local readiness_transfer_id = 0
local next_readiness_pub_time_ms = 1000

local setpoint_port_id = Parameter("CYP_SP"):get()
local setpoint_transfer_id = 0

local first_esc_feedback_port_id = Parameter("CYP_FB"):get()
local last_esc_feedback_port_id = first_esc_feedback_port_id + 7

-- Constants
local MAX_PORT_ID = 8191
local MOTOR_1_FUNC_IDX = 33
local MAX_NUMBER_OF_MOTORS = 8

local READINESS_STANDBY = 2
local READINESS_ENGAGED = 3


local next_log_time = 1000
local loop_counter = 0

-- START APPLICATION SECTION
function update()
  spin_recv()
  process_heartbeat()
  process_readiness()
  send_setpoint()

  check_perfomance()

  return update, 4 -- ms
end

function spin_recv()
  for _ = 0, 4 do
    frame = driver1:read_frame()
    if not frame then
      return
    end

    port_id = parse_frame(frame)
    if port_id >= first_esc_feedback_port_id and port_id <= last_esc_feedback_port_id then
      esc_idx = port_id - first_esc_feedback_port_id
      esc_feedback_callback(frame, esc_idx)
    end
  end
end

function process_heartbeat()
  -- uint32 uptime # [second]
  -- uint8 health
  -- uint8 mode
  -- uint8 vsscs

  if next_heartbeat_pub_time_ms >= millis() then
    return
  end
  next_heartbeat_pub_time_ms = millis() + 500

  msg = CANFrame()
  msg:id(get_msg_id(HEARTBEAT_PORT_ID, node_id))

  local now_sec = (millis() / 1000)
  msg:data(0, (now_sec & 255):toint())
  msg:data(1, ((now_sec >> 8) & 255):toint())
  msg:data(2, ((now_sec >> 16) & 255):toint())
  msg:data(3, ((now_sec >> 24) & 255):toint())
  msg:data(7, create_tail_byte(1, 1, heartbeat_transfer_id))
  msg:dlc(8)
  driver1:write_frame(msg, 1000000)
  heartbeat_transfer_id = increment_transfer_id(heartbeat_transfer_id)
end

function process_readiness()
  if readiness_port_id > MAX_PORT_ID then
    return
  end
  if next_readiness_pub_time_ms >= millis() then
    return
  end
  next_readiness_pub_time_ms = millis() + 100

  msg = CANFrame()
  msg:id( get_msg_id(readiness_port_id, node_id) )

  if arming:is_armed() then
    msg:data(0, READINESS_ENGAGED)
  else
    msg:data(0, READINESS_STANDBY)
  end

  msg:data(1, create_tail_byte(1, 1, readiness_transfer_id))
  msg:dlc(2)
  driver1:write_frame(msg, 1000000)
  readiness_transfer_id = increment_transfer_id(readiness_transfer_id)
end

function send_setpoint()
  if setpoint_port_id > MAX_PORT_ID then
    return
  end

  local setpoints = {0, 0, 0, 0, 0, 0, 0, 0}
  local number_of_motors = 0
  for motor_idx = 0, MAX_NUMBER_OF_MOTORS - 1 do
    pwm_duration_us = SRV_Channels:get_output_pwm(MOTOR_1_FUNC_IDX + motor_idx)
    if (pwm_duration_us == nil) then
      break
    end
    setpoints[motor_idx + 1] = (pwm_duration_us - 1000) * 0.001
    number_of_motors = number_of_motors + 1
  end

  payload = {}
  payload_size = vector_serialize(setpoints, number_of_motors, payload)
  can_driver_send(payload, payload_size, setpoint_port_id)
  setpoint_transfer_id = increment_transfer_id(setpoint_transfer_id)
end

function check_perfomance()
  loop_counter = loop_counter + 1
  if next_log_time <= millis() then
    next_log_time = millis() + 5000
    -- gcs:send_text(6, string.format("LUA loop times: %i", loop_counter))
    loop_counter = 0
  end
end

function esc_feedback_parse_voltage(frame)
  -- uint11 dc_voltage # [    0,+2047] * 0.2 = [     0,+409.4] volt
  return ((frame:data(0)) + ((frame:data(1) % 8) << 8))
end

function esc_feedback_parse_dc_current(frame)
  -- int12 dc_current # [-2048,+2047] * 0.2 = [-409.6,+409.4] ampere
  return ((frame:data(1) >> 3) + ((frame:data(2) % 128) << 5))
end

function esc_feedback_parse_rpm(frame)
  -- int13 velocity # [-4096,+4095] radian/second (approx. [-39114,+39104] RPM)
  return ((frame:data(4) >> 3) + (frame:data(5) << 5))
end

function esc_feedback_callback(frame, esc_idx)
  voltage_raw = esc_feedback_parse_voltage(frame)
  current_raw = esc_feedback_parse_dc_current(frame)
  rpm = esc_feedback_parse_rpm(frame)
  -- gcs:send_text(6, string.format("ESC FB %i: V=%i, I=%i", esc_idx, voltage_raw, current_raw))
  esc_telem:update_rpm(esc_idx, rpm, 0)
end

function parse_frame(frame)
  return parse_id(frame:id_signed())
end

function get_msg_id(port, node)
  return uint32_t(2422210560) + port * 256 + node
end
-- END OF THE APPLICATION SECTION

-- cyphal_can_driver START OF THE SECTION
function can_driver_send(payload, payload_size, port_id)
  can_data = {}
  can_data_size = convert_payload_to_can_data(can_data, payload, payload_size, setpoint_transfer_id)

  msg = CANFrame()
  msg:id(get_msg_id(port_id, node_id))

  for can_data_idx = 0, can_data_size - 1 do
    data_idx = can_data_idx % 8
    msg:data(data_idx, can_data[can_data_idx + 1])

    need_send = false
    if data_idx == 7 or can_data_idx == can_data_size - 1 then
      need_send = true
    end

    if need_send then
      msg:dlc(data_idx + 1)
      driver1:write_frame(msg, 1000000)
      need_send = false
    end
  end
end
-- cyphal_can_driver END OF THE SECTION


-- libcanard.lua START OF THE SECTION
local UNUSED_PORT_ID = 65535

function get_number_of_frames_by_payload_size(number_of_bytes)
  -- =IF(BYTES>0;IF(BYTES>7;CEILING((BYTES+2)/7);1);)
  number_of_frames = 0

  if number_of_bytes <= 7 then
    number_of_frames = 1
  elseif number_of_bytes <= 12 then
    number_of_frames = 2
  elseif number_of_bytes <= 19 then
    number_of_frames = 3
  elseif number_of_bytes <= 26 then
    number_of_frames = 4
  end

  return number_of_frames
end

function parse_id(id)
  service_not_message = (id >> 25) % 2
  if service_not_message == 0 then
    port_id = (id >> 8) % 8192
  else
    port_id = UNUSED_PORT_ID
  end
  return port_id
end

function create_tail_byte(frame_num, number_of_frames, transfer_id)
  tail_byte = transfer_id

  if frame_num == 1 then
    tail_byte = tail_byte + 128
  end
  if frame_num == number_of_frames then
    tail_byte = tail_byte + 64
  end
  if (frame_num % 2) == 1 then
    tail_byte = tail_byte + 32
  end

  return tail_byte
end

function convert_payload_to_can_data(buffer, payload, payload_size, transfer_id)
  number_of_frames = get_number_of_frames_by_payload_size(payload_size)
  buffer_size = 0
  tail_byte_counter = 0
  for payload_idx = 1, payload_size do
    if payload_idx % 7 == 1 and buffer_size ~= 0 then
      buffer_size = buffer_size + 1
      tail_byte_counter = tail_byte_counter + 1
      buffer[buffer_size] = create_tail_byte(tail_byte_counter, number_of_frames, transfer_id)
    end
    buffer_size = buffer_size + 1
    buffer[buffer_size] = payload[payload_idx]
  end

  if number_of_frames > 1 then
    crc = calc_crc16(payload, payload_size)
    buffer_size = buffer_size + 1
    buffer[buffer_size] = crc >> 8
    buffer_size = buffer_size + 1
    buffer[buffer_size] = crc % 256
    buffer_size = buffer_size + 1
    tail_byte_counter = tail_byte_counter + 1
    buffer[buffer_size] = create_tail_byte(tail_byte_counter, number_of_frames, transfer_id)
  end

  return buffer_size
end

function increment_transfer_id(transfer_id)
  if transfer_id >= 31 then
    return 0
  else
    return transfer_id + 1
  end
end
-- libcanard.lua END OF THE SECTION

-- libcanard_crc16.lua START OF THE SECTION
local CRC16_LOOKUP = {
  0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50A5, 0x60C6, 0x70E7, 0x8108, 0x9129, 0xA14A, 0xB16B, 0xC18C,
  0xD1AD, 0xE1CE, 0xF1EF, 0x1231, 0x0210, 0x3273, 0x2252, 0x52B5, 0x4294, 0x72F7, 0x62D6, 0x9339, 0x8318,
  0xB37B, 0xA35A, 0xD3BD, 0xC39C, 0xF3FF, 0xE3DE, 0x2462, 0x3443, 0x0420, 0x1401, 0x64E6, 0x74C7, 0x44A4,
  0x5485, 0xA56A, 0xB54B, 0x8528, 0x9509, 0xE5EE, 0xF5CF, 0xC5AC, 0xD58D, 0x3653, 0x2672, 0x1611, 0x0630,
  0x76D7, 0x66F6, 0x5695, 0x46B4, 0xB75B, 0xA77A, 0x9719, 0x8738, 0xF7DF, 0xE7FE, 0xD79D, 0xC7BC, 0x48C4,
  0x58E5, 0x6886, 0x78A7, 0x0840, 0x1861, 0x2802, 0x3823, 0xC9CC, 0xD9ED, 0xE98E, 0xF9AF, 0x8948, 0x9969,
  0xA90A, 0xB92B, 0x5AF5, 0x4AD4, 0x7AB7, 0x6A96, 0x1A71, 0x0A50, 0x3A33, 0x2A12, 0xDBFD, 0xCBDC, 0xFBBF,
  0xEB9E, 0x9B79, 0x8B58, 0xBB3B, 0xAB1A, 0x6CA6, 0x7C87, 0x4CE4, 0x5CC5, 0x2C22, 0x3C03, 0x0C60, 0x1C41,
  0xEDAE, 0xFD8F, 0xCDEC, 0xDDCD, 0xAD2A, 0xBD0B, 0x8D68, 0x9D49, 0x7E97, 0x6EB6, 0x5ED5, 0x4EF4, 0x3E13,
  0x2E32, 0x1E51, 0x0E70, 0xFF9F, 0xEFBE, 0xDFDD, 0xCFFC, 0xBF1B, 0xAF3A, 0x9F59, 0x8F78, 0x9188, 0x81A9,
  0xB1CA, 0xA1EB, 0xD10C, 0xC12D, 0xF14E, 0xE16F, 0x1080, 0x00A1, 0x30C2, 0x20E3, 0x5004, 0x4025, 0x7046,
  0x6067, 0x83B9, 0x9398, 0xA3FB, 0xB3DA, 0xC33D, 0xD31C, 0xE37F, 0xF35E, 0x02B1, 0x1290, 0x22F3, 0x32D2,
  0x4235, 0x5214, 0x6277, 0x7256, 0xB5EA, 0xA5CB, 0x95A8, 0x8589, 0xF56E, 0xE54F, 0xD52C, 0xC50D, 0x34E2,
  0x24C3, 0x14A0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405, 0xA7DB, 0xB7FA, 0x8799, 0x97B8, 0xE75F, 0xF77E,
  0xC71D, 0xD73C, 0x26D3, 0x36F2, 0x0691, 0x16B0, 0x6657, 0x7676, 0x4615, 0x5634, 0xD94C, 0xC96D, 0xF90E,
  0xE92F, 0x99C8, 0x89E9, 0xB98A, 0xA9AB, 0x5844, 0x4865, 0x7806, 0x6827, 0x18C0, 0x08E1, 0x3882, 0x28A3,
  0xCB7D, 0xDB5C, 0xEB3F, 0xFB1E, 0x8BF9, 0x9BD8, 0xABBB, 0xBB9A, 0x4A75, 0x5A54, 0x6A37, 0x7A16, 0x0AF1,
  0x1AD0, 0x2AB3, 0x3A92, 0xFD2E, 0xED0F, 0xDD6C, 0xCD4D, 0xBDAA, 0xAD8B, 0x9DE8, 0x8DC9, 0x7C26, 0x6C07,
  0x5C64, 0x4C45, 0x3CA2, 0x2C83, 0x1CE0, 0x0CC1, 0xEF1F, 0xFF3E, 0xCF5D, 0xDF7C, 0xAF9B, 0xBFBA, 0x8FD9,
  0x9FF8, 0x6E17, 0x7E36, 0x4E55, 0x5E74, 0x2E93, 0x3EB2, 0x0ED1, 0x1EF0
}

function crc16_add_byte(prev_crc, byte_value)
  return ((prev_crc << 8) & 0xFFFF) ~ CRC16_LOOKUP[((prev_crc >> 8) ~ byte_value) + 1]
end

function calc_crc16(byte_array, num_bytes)
  start_byte = 1
  local crc = 0xFFFF
  for i = 1, num_bytes do
    local byte_value = byte_array[i] & 0xFF
    crc = crc16_add_byte(crc, byte_value)
  end
  return crc
end
-- libcanard_crc16.lua END OF THE SECTION

-- libcanard_ds015.lua END OF THE SECTION
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
-- libcanard_ds015.lua END OF THE SECTION

-- libcanard_type_cast.lua START OF THE SECTION
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
-- libcanard_type_cast.lua END OF THE SECTION


-- Entry point
if (param_cyp_tests:get() >= 1) then
  gcs:send_text(5, "LUA Cyphal unit tests enabled!")
end

if (param_cyp_enable:get() >= 1) then
  gcs:send_text(5, "LUA Cyphal enabled!")
  return update()
end
