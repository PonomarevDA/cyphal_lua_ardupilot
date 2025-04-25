package.path = package.path .. ";libcanard/?.lua"
require 'libcanard'
require 'libcanard_type_cast'
require 'libcanard_crc16'
require 'libcanard_ds015'
require 'libcanard_assert'


function test_parse_id()
  assert_eq(65535, parse_id(34067071))  -- srv, skip for a while
  assert_eq(2002, parse_id(512639))     -- msg node_id=127, subject_id=2002 (synthetic)
  assert_eq(2002, parse_id(275239551))  -- msg node_id=127, subject_id=2002 (real example)
end

function test_get_number_of_frames_by_payload_size()
  assert_eq(1, get_number_of_frames_by_payload_size(7))
  assert_eq(2, get_number_of_frames_by_payload_size(8))
  assert_eq(2, get_number_of_frames_by_payload_size(12))
  assert_eq(3, get_number_of_frames_by_payload_size(13))
  assert_eq(3, get_number_of_frames_by_payload_size(19))
  assert_eq(4, get_number_of_frames_by_payload_size(20))
end

function test_create_tail_byte()
  assert_eq(244, create_tail_byte(1, 1, 20))
  assert_eq(174, create_tail_byte(1, 2, 14))
  assert_eq(88, create_tail_byte(2, 2, 24))
  assert_eq(13, create_tail_byte(2, 3, 13))
end

function test_array_serialize()
  payload = {}

  setpoints = {1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800}
  payload_size = array_serialize(setpoints, 8, payload)
  assert_eq(17, payload_size)

  setpoints = {0, 0, 0, 0, 0, 0, 0, 0}
  payload_size = array_serialize(setpoints, 8, payload)
  assert_eq(17, payload_size)
  expected_buffer = {
    0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA4,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04,
    0x00, 0x00, 0x00, 0x40, 0xFC, 0x64
  }
  expected_buffer_size = 22
  transfer_id = 4
  buffer = {}
  buffer_size = convert_payload_to_can_data(buffer, payload, payload_size, transfer_id)
  assert_eq(expected_buffer_size, buffer_size)
  for idx = 1, buffer_size do
    assert_eq(expected_buffer[idx], buffer[idx])
  end

  payload = {
    0x08, 0x32, 0x00, 0x33, 0x00, 0x34, 0x00,
    0x35, 0x00, 0x36, 0x00, 0x37, 0x00, 0x37,
    0x00, 0x37, 0x00
  }
  transfer_id = 12
  expected_buffer = {
    0x08, 0x32, 0x00, 0x33, 0x00, 0x34, 0x00, 0xAC,
    0x35, 0x00, 0x36, 0x00, 0x37, 0x00, 0x37, 0x0C,
    0x00, 0x37, 0x00, 0x48, 0xC3, 0x6C
  }
  buffer = {}
  buffer_size = convert_payload_to_can_data(buffer, payload, payload_size, transfer_id)
  assert_eq(22, buffer_size)
  for idx = 1, buffer_size do
    assert_eq(expected_buffer[idx], buffer[idx])
  end
end

function test_vector_serialize()
  payload = {}
  buffer = {}

  -- 1. Empty setpoint
  number_of_setpoints = 8
  setpoints = {0, 0, 0, 0, 0, 0, 0, 0}
  transfer_id = 7

  expected_buffer = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA7,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07,
    0x00, 0x00, 0x6A, 0x0A, 0x67
  }
  expected_buffer_size = 21

  payload_size = vector_serialize(setpoints, number_of_setpoints, payload)
  buffer_size = convert_payload_to_can_data(buffer, payload, payload_size, transfer_id)

  assert_eq(expected_buffer_size, buffer_size)
  for idx = 1, buffer_size do
    assert_eq(expected_buffer[idx], buffer[idx])
  end

  -- 2. Not empty setpoint
  number_of_setpoints = 8
  setpoints = {0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7}
  transfer_id = 18

  payload_size = vector_serialize(setpoints, number_of_setpoints, payload)
  buffer_size = convert_payload_to_can_data(buffer, payload, payload_size, transfer_id)

  expected_buffer = {
    0x00, 0x00, 0x66, 0x2E, 0x66, 0x32, 0xCD, 0xB2,
    0x34, 0x66, 0x36, 0x00, 0x38, 0xCD, 0x38, 0x12,
    0x9A, 0x39, 0xA2, 0xF2, 0x72
  }
  expected_buffer_size = 21

  assert_eq(expected_buffer_size, buffer_size)
  for idx = 1, buffer_size do
    assert_eq(expected_buffer[idx], buffer[idx])
  end

  -- 3. Setpoint 1 frame
  number_of_setpoints = 3
  setpoints = {0, 0, 0}
  transfer_id = 7

  expected_buffer = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xE7
  }
  expected_buffer_size = 7

  payload_size = vector_serialize(setpoints, number_of_setpoints, payload)
  buffer_size = convert_payload_to_can_data(buffer, payload, payload_size, transfer_id)

  assert_eq(expected_buffer_size, buffer_size)
  for idx = 1, buffer_size do
    assert_eq(expected_buffer[idx], buffer[idx])
  end
end

test_parse_id()
test_get_number_of_frames_by_payload_size()
test_create_tail_byte()
test_array_serialize()
test_vector_serialize()
