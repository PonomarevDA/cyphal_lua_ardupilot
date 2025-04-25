#!/usr/bin/env python3
"""
Upload a Lua script to ArduPilot's SD card APM/scripts folder via MAVLink FTP.
Requires: pip install pymavlink
"""

import os
import shutil
import hashlib
import argparse
import pymavlink
from pymavlink import mavftp

def md5(filename: str):
    """Calculate the MD5 checksum of a file."""
    md5_hash = hashlib.md5()
    with open(filename, 'rb') as file:
        md5_hash.update(file.read())

    return md5_hash.hexdigest()

def mavftp_ls(ftp: mavftp.MAVFTP, path: str) -> mavftp.FtpError:
    arguments = [] if path in ("/", "") else [path]
    ret = ftp.cmd_list(arguments)
    ret.display_message()
    if ret.error_code != 0 or ret.system_error != 0:
        return ret

    print(f"Content of {path}:")
    for entry in ftp.list_result:
        kind = "DIR " if entry.is_dir else "FILE"
        print(f"  {kind} {entry.name:20} {entry.size_b:8d} bytes")

    return ret

def mavftp_put(ftp, remote, local, timeout=10):
    print(f"Uploading {local!r} → {remote!r}…")
    ftp.cmd_put([local, remote])
    ret = ftp.process_ftp_reply('CreateFile', timeout=timeout)
    ret.display_message()

def mavftp_get(ftp, remote, local, timeout=10):
    if os.path.exists(local):
        os.remove(local)

    ftp.cmd_get([remote, local])
    ret = ftp.process_ftp_reply('OpenFileRO', timeout=timeout)
    ret.display_message()

    # Hack. For some reasons mavftp can download a file, save it to the temp dir,
    # but doesn't copy it to the destination dir.
    # If it happens, let's copy it manually.
    mavftp_temp_filename = "/tmp/temp_mavftp_file"
    if not os.path.exists(local) and os.path.exists(mavftp_temp_filename):
        shutil.copy(mavftp_temp_filename, local)

def upload_lua_script(connection_string, local_filename, remote_dir, reboot=False):
    master = pymavlink.mavutil.mavlink_connection(connection_string, baud=115200)

    try:
        master.wait_heartbeat(timeout=10)
    except Exception as err:
        print(f"Failed to get heartbeat: {err}")
        return

    print(f"Heartbeat from system {master.target_system}, component {master.target_component}")
    ftp = mavftp.MAVFTP(master,
                        target_system=master.target_system,
                        target_component=master.target_component)

    mavftp_put(ftp, f'{remote_dir}/{local_filename}', local_filename)
    mavftp_ls(ftp, remote_dir)
    mavftp_get(ftp, f'{remote_dir}/{local_filename}', f"{local_filename}_back")

    print("Local MD5:  ", md5(local_filename))
    print("Remote MD5: ", md5(f"{local_filename}_back"))

    if reboot:
        print("Rebooting autopilot...")
        param1 = 1 # Reboot autopilot
        param6 = 20190226 # force

        master.mav.command_long_send(
            master.target_system,
            master.target_component,
            pymavlink.mavutil.mavlink.MAV_CMD_PREFLIGHT_REBOOT_SHUTDOWN,
            0,
            param1, 0, 0, 0, 0, param6, 0
        )
        print("[INFO] Reboot command sent.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Upload a .lua script to ArduPilot SD card")
    parser.add_argument("--connection", "-c", required=True,
                        help="MAVLink connection string (e.g. /dev/ttyACM0 or COM3)")
    parser.add_argument("--file", "-f", default="Cyphal.lua",
                        help="Path to local .lua script")
    parser.add_argument("--reboot", action="store_true",
                        help="Reboot the autopilot after uploading the script")
    args = parser.parse_args()

    upload_lua_script(args.connection, args.file, "/APM/scripts", args.reboot)
