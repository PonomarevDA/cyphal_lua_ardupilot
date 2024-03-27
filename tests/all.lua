package.path = package.path .. ";libcanard/?.lua"
package.path = package.path .. ";tests/?.lua"
require 'test_crc16'
require 'test_ds015'
require 'test_libcanard'
require 'test_type_cast'
