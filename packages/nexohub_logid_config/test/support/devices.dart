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

/// A small stand-in for the libevdev name tables (the real catalog comes
/// from nexohub_input_keys).
final class FakeEvdevNames implements EvdevNames {
  /// Creates the fake.
  const FakeEvdevNames();

  static const _keys = {
    'KEY_A': 30, 'KEY_C': 46, 'KEY_S': 31, 'KEY_V': 47, 'KEY_TAB': 15, //
    'KEY_LEFTCTRL': 29, 'KEY_LEFTSHIFT': 42, 'KEY_LEFTALT': 56,
    'KEY_LEFTMETA': 125, 'KEY_RIGHT': 106, 'KEY_VOLUMEUP': 115,
    'BTN_LEFT': 0x110,
  };
  static const _axes = {
    'REL_X': 0, 'REL_Y': 1, 'REL_HWHEEL': 6, 'REL_WHEEL': 8, //
    'REL_WHEEL_HI_RES': 11, 'REL_HWHEEL_HI_RES': 12,
  };

  @override
  int? keyCode(String name) => _keys[name];

  @override
  int? relativeAxisCode(String name) => _axes[name];
}
