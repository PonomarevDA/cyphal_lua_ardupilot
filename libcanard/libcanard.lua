require 'libcanard_crc16'

local UNUSED_PORT_ID = 65535

-- =IF(BYTES>0;IF(BYTES>7;CEILING((BYTES+2)/7);1);)
function get_number_of_frames_by_payload_size(number_of_bytes)
  local number_of_frames = 0

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
  local service_not_message = (id >> 25) % 2
  local port_id
  if service_not_message == 0 then
    port_id = (id >> 8) % 8192
  else
    port_id = UNUSED_PORT_ID
  end
  return port_id
end

function create_tail_byte(frame_num, number_of_frames, transfer_id)
  local tail_byte = transfer_id

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
  local number_of_frames = get_number_of_frames_by_payload_size(payload_size)
  local buffer_size = 0
  local tail_byte_counter = 0
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
    local crc = calc_crc16(payload, payload_size)
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
  return (transfer_id + 1) % 32
end
