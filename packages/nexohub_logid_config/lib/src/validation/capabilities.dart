// What a device supports, as reported by logid (D-Bus probe) or the Nexo
// device database. Every field is nullable: null means "unknown", and the
// validator then skips the checks that depend on it.

/// One HID++ control (button) of a device.
final class ButtonCapability {
  /// Creates a button capability.
  const ButtonCapability({
    required this.cid,
    required this.remappable,
    required this.gestureSupport,
  });

  /// HID++ control ID.
  final int cid;

  /// Whether logid can divert it (`Remappable` on D-Bus).
  final bool remappable;

  /// Whether raw XY movement can be diverted (`GestureSupport` on D-Bus).
  final bool gestureSupport;
}

/// The DPI values one sensor accepts (`GetDPIs` on D-Bus).
sealed class DpiCapability {
  const DpiCapability();
}

/// A continuous range: `min` to `max` in steps of `step`.
final class DpiRange extends DpiCapability {
  /// Creates a range.
  const DpiRange({required this.min, required this.max, required this.step});

  /// Lowest DPI.
  final int min;

  /// Highest DPI.
  final int max;

  /// Increment between valid values.
  final int step;
}

/// A fixed list of DPI values.
final class DpiList extends DpiCapability {
  /// Creates a list.
  const DpiList(this.values);

  /// Accepted values.
  final List<int> values;
}

/// Capabilities of one device, keyed by its HID++ name in the validator.
final class LogidDeviceCapabilities {
  /// Creates capabilities; leave unknown fields null.
  const LogidDeviceCapabilities({
    this.buttons,
    this.dpiSensors,
    this.smartShift,
    this.torque,
    this.hiresScroll,
    this.thumbWheel,
    this.thumbWheelTouch,
    this.thumbWheelTap,
    this.thumbWheelProxy,
    this.hostCount,
  });

  /// Every control of the device (`Buttons.Enumerate`).
  final List<ButtonCapability>? buttons;

  /// One entry per DPI sensor.
  final List<DpiCapability>? dpiSensors;

  /// SmartShift feature present.
  final bool? smartShift;

  /// SmartShift torque supported (`TorqueSupport`).
  final bool? torque;

  /// Hi-res wheel feature present.
  final bool? hiresScroll;

  /// Thumb wheel present.
  final bool? thumbWheel;

  /// Thumb wheel reports touch.
  final bool? thumbWheelTouch;

  /// Thumb wheel reports taps.
  final bool? thumbWheelTap;

  /// Thumb wheel reports finger proximity.
  final bool? thumbWheelProxy;

  /// Easy-Switch channels.
  final int? hostCount;

  /// The capability of [cid], or null when absent/unknown.
  ButtonCapability? button(int cid) {
    for (final b in buttons ?? const <ButtonCapability>[]) {
      if (b.cid == cid) return b;
    }
    return null;
  }
}

/// The DPI logid actually sets for [configured] on a sensor with
/// [capability] (`DPI::getClosestDPI`, src/logid/features/DPI.cpp), or null
/// when logid leaves the DPI unchanged (0).
///
/// Reproduces logid exactly, including the conversion to 16 bits and, for
/// fixed lists, its comparison that picks the largest value instead of the
/// closest one when there is no exact match.
int? effectiveDpi(int configured, DpiCapability capability) {
  if (configured == 0) return null; // "if (dpi != 0)" in DPI::configure
  final dpi = configured & 0xFFFF; // getClosestDPI takes a uint16_t
  switch (capability) {
    case DpiRange(:final min, :final max, :final step):
      if (dpi >= min && dpi <= max && (dpi - min) % step == 0) return dpi;
      if (dpi > max) return max;
      if (dpi < min) return min;
      return min + ((dpi - min) / step).round() * step;
    case DpiList(:final values):
      if (values.contains(dpi)) return dpi;
      // std::min_element with `(dpi - a) < (dpi - b)` → the largest value.
      return values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);
  }
}
