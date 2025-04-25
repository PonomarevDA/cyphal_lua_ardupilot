#!/usr/bin/env python3
# This software is distributed under the terms of the MIT License.
# Copyright (c) 2023-2025 Dmitry Ponomarev.
# Author: Dmitry Ponomarev <ponomarevda96@gmail.com>
import time
import asyncio
import pycyphal.application
import uavcan
import zubax.telega.CompactFeedback_1_0 as CompactFeedback_1_0
import reg.udral.physics.optics

MIN_VOLTAGE = 0.0
MAX_VOLTAGE = +409.4
MIN_CURRENT = -409.6
MAX_CURRENT = +409.4
MIN_RPM = -39114
MAX_RPM = +39104
MIN_DEMAND_FACTOR_PCT = -128
MAX_DEMAND_FACTOR_PCT = +127

async def heartbeat_callback(data, transfer_from):
    # print(data)
    pass

def serialize_compact_feedback(voltage: float,
                               current: float,
                               rpm: int,
                               demand_factor_pct: float) -> CompactFeedback_1_0:
    """
    uint11  dc_voltage                  [    0,+2047] * 0.2 = [     0,+409.4] volt
    int12   dc_current                  [-2048,+2047] * 0.2 = [-409.6,+409.4] ampere
    int12   phase_current_amplitude     ditto
    int13   velocity                    [-4096,+4095] radian/second (approx. [-39114,+39104] RPM)
    int8    demand_factor_pct           [ -128, +127] percent
    """
    return CompactFeedback_1_0(int(max(0, min(2047, voltage * 5))),
                               int(max(-2048, min(2047, current * 5))),
                               int(max(-2048, min(2047, current * 5))),
                               int(max(-4096, min(4095, rpm * 0.1047))),
                               int(max(-128, min(127, demand_factor_pct))))

async def main():
    node = pycyphal.application.make_node(
        uavcan.node.GetInfo_1_0.Response(
            uavcan.node.Version_1_0(major=1, minor=0),
            name="co.raccoonlab.spec_checker"
        )
    )

    node.start()

    feedback_publishers = [
        node.make_publisher(CompactFeedback_1_0, 3000),
        # node.make_publisher(CompactFeedback_1_0, 3001),
        # node.make_publisher(CompactFeedback_1_0, 3002),
        # node.make_publisher(CompactFeedback_1_0, 3003),
    ]

    heartbeat_sub = node.make_subscriber(uavcan.node.Heartbeat_1_0)
    heartbeat_sub.receive_in_background(heartbeat_callback)

    for _ in range(10000):
        fraction = ((time.time() % 14) / 14) * 1.4 - 0.2
        voltage = MIN_VOLTAGE + fraction * (MAX_VOLTAGE - MIN_VOLTAGE)
        current = MIN_CURRENT + fraction * (MAX_CURRENT - MIN_CURRENT)
        rpm = MIN_RPM + fraction * (MAX_RPM - MIN_RPM)
        demand_factor_pct = MIN_DEMAND_FACTOR_PCT + fraction * (MAX_DEMAND_FACTOR_PCT - MIN_DEMAND_FACTOR_PCT)

        for fb_pub in feedback_publishers:
            await fb_pub.publish(serialize_compact_feedback(voltage, current, rpm, demand_factor_pct))
        await asyncio.sleep(0.5) # 0.1

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("Aborted by KeyboardInterrupt.")
