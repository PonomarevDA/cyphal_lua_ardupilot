require 'libcanard_assert'
require 'libcanard'
require 'libcanard_ds015'

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
  setpoints = {0, 0, 0, 0, 0, 0, 0, 0}
  transfer_id = 7

  expected_buffer = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA7,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07,
    0x00, 0x00, 0x6A, 0x0A, 0x67
  }
  expected_buffer_size = 21

  payload_size = vector_serialize(setpoints, 8, payload)
  buffer_size = convert_payload_to_can_data(buffer, payload, payload_size, transfer_id)

  assert_eq(expected_buffer_size, buffer_size)
  for idx = 1, buffer_size do
    assert_eq(expected_buffer[idx], buffer[idx])
  end

  -- 2. Not empty setpoint
  setpoints = {0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7}
  transfer_id = 18

  payload_size = vector_serialize(setpoints, 8, payload)
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
end

function test_compact_feedback_deserialize()
  assert_eq(0, compact_feedback_deserialize({0, 248, 0, 0, 0, 0, 0}, 7).voltage)
  assert_eq(2047, compact_feedback_deserialize({255, 7, 0, 0, 0, 0, 0}, 7).voltage)

  assert_eq(0, compact_feedback_deserialize({0, 7, 0, 0, 0, 0, 0}, 7).dc_current)
  assert_eq(2047, compact_feedback_deserialize({0, 248, 63, 0, 0, 0, 0}, 7).dc_current)

  assert_eq(0, compact_feedback_deserialize({0, 0, 0, 0, 0, 0, 0}, 7).rpm)
  assert_eq(4095, compact_feedback_deserialize({0, 0, 0, 0, 248, 127, 0}, 7).rpm)
end

test_array_serialize()
test_vector_serialize()
test_compact_feedback_deserialize()
