# Cyphal ESC Driver

This driver implements support for Cyphal ESCs such as Myxa, kotleta20 and
others. It supports:
- [Heartbeat](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/uavcan/node/7509.Heartbeat.1.0.dsdl),
- [ESC service](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/actuator/esc/_.0.1.dsdl) based on [setpoint](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/actuator/common/sp/_.0.1.dsdl), [readiness](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/reg/udral/service/common/Readiness.0.1.dsdl) and [Telega/CompactFeedback](https://github.com/Zubax/zubax_dsdl/blob/master/zubax/telega/CompactFeedback.1.0.dsdl) for up to 8 ESC.

> The driver doesn't support [node.GetInfo](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/uavcan/node/430.GetInfo.1.0.dsdl) and [register interface](https://github.com/OpenCyphal/public_regulated_data_types/blob/master/uavcan/register/384.Access.1.0.dsdl).

## How to use

This driver should be loaded by placing the lua script in the
APM/scripts directory on the microSD card, which can be done either
directly or via MAVFTP. The following key parameters should be set to
start the script and configure CAN driver:

||||
|-|-|-|
| SCR_ENABLE      | 1 | 1 means scripting is enabled, 0 means disabled
| CAN_D1_PROTOCOL | 10 | 10 means scripting
| CAN_P1_BITRATE  | 1000000 | Default bitrate for most of the applications
| CAN_P1_DRIVER   | First driver

then the flight controller should be rebooted and parameters should be
refreshed.

Once loaded the Cyphal parameters will appear and should be configured:

||||
|-|-|-|
| CYP_ENABLE      | 1 | 1 means Cyphal is enabled, 0 means disabled
| CYP_NODE_ID     | 1-127 | Node identifier in Cyphal-network
| CYP_FB          | 1-8191 | ESC Feedback port id. Enabled if less then 8191, otherwise disabled.
| CYP_RD          | 1-8191 | Readiness port id. Enabled if less then 8191, otherwise disabled.
| CYP_SP          | 1-8191 | Setpoint port id for the first ESC. Enabled if less then 8191, otherwise disabled.
| CYP_TESTS       | 0 | If set to 1, self tests will be runned at the beginning of the application.

## Links

Reference: https://opencyphal.org/specification/Cyphal_Specification.pdf

## Which firmware to use?

You can use the latest official firmware.

A hint how to build and upload for CUAVv5:

```
./waf list_boards
./waf configure --board CUAVv5
./waf copter
./waf --targets bin/arducopter --upload
```

## Debugging with Yakut

```
y sub 2343:reg.udral.service.common.Readiness
y sub 2342:reg.udral.service.actuator.common.sp.Vector8
```

## Known issues

- `Insufficent memory loading`. Try to disable some feature as it is recommended on [the ardupilot forum](https://discuss.ardupilot.org/t/lua-script-pre-arm-error/86834). For example, `LOG_FILE_BUFSIZE = 8` can help.
