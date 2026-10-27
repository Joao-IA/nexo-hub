import 'package:nexohub_logid_config/nexohub_logid_config.dart';

/// MX Master 3S as probed on the maintainer's device (spike S2/S5,
/// 2026-10-27): logid D-Bus + thumb-wheel capabilities from logid -v.
const mxMaster3s = LogidDeviceCapabilities(
  buttons: [
    ButtonCapability(cid: 0x50, remappable: false, gestureSupport: false),
    ButtonCapability(cid: 0x51, remappable: false, gestureSupport: false),
    ButtonCapability(cid: 0x52, remappable: true, gestureSupport: true),
    ButtonCapability(cid: 0x53, remappable: true, gestureSupport: true),
    ButtonCapability(cid: 0x56, remappable: true, gestureSupport: true),
    ButtonCapability(cid: 0xc3, remappable: true, gestureSupport: true),
    ButtonCapability(cid: 0xc4, remappable: true, gestureSupport: true),
    ButtonCapability(cid: 0xd7, remappable: true, gestureSupport: true),
  ],
  dpiSensors: [DpiRange(min: 200, max: 8000, step: 50)],
  smartShift: true,
  torque: false,
  hiresScroll: true,
  thumbWheel: true,
  thumbWheelTouch: true,
  thumbWheelTap: true,
  thumbWheelProxy: true,
  hostCount: 3,
);
