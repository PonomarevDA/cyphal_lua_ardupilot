[![linter](https://github.com/PonomarevDA/cyphal_lua_ardupilot/actions/workflows/linter.yml/badge.svg)](https://github.com/PonomarevDA/cyphal_lua_ardupilot/actions/workflows/linter.yml) [![tests](https://github.com/PonomarevDA/cyphal_lua_ardupilot/actions/workflows/unit_tests.yml/badge.svg)](https://github.com/PonomarevDA/cyphal_lua_ardupilot/actions/workflows/unit_tests.yml)
![coverage](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/PonomarevDA/466f0869d81f7092ff682b1e6e964812/raw/test.json)

# ArduPilot Cyphal/CAN LUA Driver

The driver implements Cyphal [ESC service](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/actuator/esc/_.0.1.dsdl) support for up to 8 ESC like [Myxa](https://cyphal.store/products/zubax-ad0505-myxa-esc), [Mini node](https://cyphal.store/products/raccoonlab-cyphal-can-mininode) and [kotleta20](https://holybro.com/products/kotleta20).

It publishes:
- [uavcan.node.Heartbeat](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/uavcan/node/7509.Heartbeat.1.0.dsdl) with 1 Hz rate,
- [reg.udral.service.common.Readiness](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/common/Readiness.0.1.dsdl) with 10 Hz rate,
- [reg.udral.service.actuator.common.sp](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/actuator/common/sp/_.0.1.dsdl) with maximum possible rate.

It subscribes on:
- [zubax.telega.CompactFeedback](https://github.com/Zubax/zubax_dsdl/blob/master/zubax/telega/CompactFeedback.1.0.dsdl).

The driver introduces the following ArduPilot parameters:

||||
|-|-|-|
| CYP_ENABLE      | 1 | 1 means Cyphal is enabled, 0 means disabled </br> Default: Enabled |
| CYP_NODE_ID     | 1-127 | Node identifier in Cyphal-network. Usually, 127 is reserved for debugging tools and 1 is used for an autopilot. </br> Default: 1 |
| CYP_TESTS       | 0 | If set to 1, the driver analysis his own performance and enables extra verbosity to GCS </br> Default: Disabled |.
| CYP_RD          | 1-8191 | Readiness port id. Enabled if less then 8191, otherwise disabled. </br> Default: 65535 (disabled). |
| CYP_SP          | 1-8191 | Setpoint port id for ESCs. Enabled if less then 8191, otherwise disabled. </br> Default: 65535 (disabled). |
| CYP_FB          | 1-8191 | ESC Feedback [array of port id](https://forum.opencyphal.org/t/rfc-add-array-of-ports/1878). Enabled if less then 8191, otherwise disabled. When enabled, it occupies 8 consecutive port identifiers. For example, if it is 3000, it will occupy [3000, 3007] identifiers. </br> Default: 65535 (disabled). |

**Limitation**

The driver does not provide support for the following features:
- [uavcan.node.GetInfo](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/uavcan/node/430.GetInfo.1.0.dsdl)
- [Register interface](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/uavcan/register/384.Access.1.0.dsdl)
- [uavcan.node.port.List](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/uavcan/node/port/7510.List.1.0.dsdl)

## 1. Step 1. Upload ArduPilot firmware

Any modern flight controller and ArduPilot firmware with scripting support should be suitable.

Tested on `Pixhawk6C`, `CuavV6X` and `CubeOrange` with `Copter` and `ArduPlane` firmware `v4.4.4` and `v4.4.7`.

**Option 1.** Upload the latest stable fimware with QGroundControl or MissionPlanner.

| [QGroundControl](https://docs.qgroundcontrol.com/Stable_V4.3/en/qgc-user-guide/setup_view/firmware.html) | [MissionPlanner](https://ardupilot.org/planner/docs/common-loading-firmware-onto-pixhawk.html) |
|-|-|
| <img src="https://raw.githubusercontent.com/wiki/PonomarevDA/cyphal_lua_ardupilot/assets/firmware_setup.png" alt="drawing" width="215"> | <img src="https://ardupilot.org/planner/_images/Pixhawk_InstallFirmware.jpg" alt="drawing" width="485"/> |

**Option 2.** Build and upload firmware manually from source code.

```bash
./waf list_boards
./waf configure --board CubeOrange # Pixhawk6C, Pixhawk6X
./waf copter
./waf --targets bin/arducopter --upload
```

## Step 2. Load Cyphal.lua to microSD card

This driver should be loaded by placing the lua script in the
`APM/scripts` directory on the microSD card.

**Opion 1.** Upload `Cyphal.lua` script with a helper python script

```bash
pip install -r requirements.txt
./upload.py -c /dev/ttyACM0 # use a path to the flight controler
```

**Option 2.** Upload the script with card reader or using MissionPlanner

| Copy directly | [Using MAVFtp](https://ardupilot.org/copter/docs/common-lua-scripts.html) |
|-|-|
| <img src="https://raw.githubusercontent.com/wiki/PonomarevDA/cyphal_lua_ardupilot/assets/sdcard.png" alt="drawing" width="385"> | <img src="https://ardupilot.org/copter/_images/scripting-MP-mavftp.png" alt="drawing" width="315"/> |

## Step 3. Configure parameters

The following parameters should be set to start the script and configure the CAN driver:

|||
|-|-|
| [SCR_ENABLE](https://ardupilot.org/plane/docs/parameters.html#scr-parameters) | 1 - means scripting is enabled, 0 means disabled
| [CAN_D1_PROTOCOL](https://ardupilot.org/plane/docs/parameters.html#can-d1-parameters) | 10 - means scripting
| [CAN_P1_DRIVER](https://ardupilot.org/plane/docs/parameters.html#can-p1-driver-index-of-virtual-driver-to-be-used-with-physical-can-interface) | First driver
| [CAN_P1_BITRATE](https://ardupilot.org/plane/docs/parameters.html#can-p1-bitrate-bitrate-of-can-interface)  | 1000000 - Default bitrate for most of the applications

Then reboot the flight controller and Cyphal parameters should appear. If the parameters don't appear, try `Refresh` button in QGC or restart the GCS. You need to configure these:

|||
|-|-|
| CYP_SP | Enable publishing [sp.Vector](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/actuator/common/sp/_.0.1.dsdl). Choose any value withing [1, 7167]. For example, 2000. |
| CYP_RD | Enable publishing [Readiness](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/common/Readiness.0.1.dsdl). Choose any value withing [1, 7167]. For example, 2001. |
| CYP_FB  | Enable subscribing on a group of [CompactFeedback](https://github.com/Zubax/zubax_dsdl/blob/master/zubax/telega/CompactFeedback.1.0.dsdl)s. Choose any value withing [1, 7167]. For example, 3000. |

Then reboot the flight controller.

## Step 4. Try with yakut

Configure the yakut-related environment variables, connect autopilot and CAN-sniffer together.

<img src="https://github.com/ZilantRobotics/innopolis_vtol_dynamics/raw/master/docs/img/sniffer_connection.png" alt="drawing" width="300"/>

If you run `y mon`, you should get:

<img src="https://raw.githubusercontent.com/wiki/PonomarevDA/cyphal_lua_ardupilot/assets/y_mon.png" alt="drawing" width="500">

Here, we have 2 nodes: autopilot with node_id=1 (it is configured in `CYP_NODE_ID`) and yakut with node_id=127. The autopilot publishes setpoint with port_id=2000 (`CYP_SP`) with ~234 Hz and readiness with port_id=2001 (`CYP_RD`) with ~10 Hz.

> Since the node doesn't support anything except `uavcan.node.Heartbeat`, it doesn't have a name and registers are not avaliable via Cyphal/CAN interface.

Additionally, you can subscribes to the setpoint and readiness topics:

```
y sub 2001:reg.udral.service.common.Readiness
y sub 2000:reg.udral.service.actuator.common.sp.Vector8
```

## Step 5. Try with emulated ESC

```bash
./emulate_zubax_myxa_feedback.py
```

## KNOWN ISSUES

**1. `Insufficent memory loading`**

Try to disable some feature as it is recommended on [the ardupilot forum](https://discuss.ardupilot.org/t/lua-script-pre-arm-error/86834).

For example, `LOG_FILE_BUFSIZE = 8` can help.

**2. Why Cyphal paramters are float?**

[Docs](https://ardupilot.org/copter/docs/common-scripting-parameters.html) says `all scripting defined parameters are of type FLOAT, ie floating point numbers`.
