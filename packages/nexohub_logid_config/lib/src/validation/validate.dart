// Semantic validation: things logid 0.3.5 accepts in the file but that break,
// crash or silently do nothing at runtime. Each rule cites the logid code
// that justifies it (commit 628ab937, src/logid/…).
import 'package:nexohub_input_keys/nexohub_input_keys.dart';

import '../model/model.dart';
import 'capabilities.dart';

/// How bad a finding is.
enum ValidationSeverity {
  /// Breaks the device configuration, crashes logid or never works.
  /// Nexo refuses to apply a configuration with errors.
  error,

  /// Works differently from what the setting says, or only partly.
  warning,

  /// Worth knowing; nothing is wrong.
  info,
}

/// Every rule of the validator. The UI translates by code, using
/// [ValidationIssue.params].
enum ValidationCode {
  // ---- global ---------------------------------------------------------
  /// `workers` < 1: logid starts no worker thread and queued work never runs
  /// (util/task.cpp `init_workers`).
  workersInvalid(ValidationSeverity.error),

  /// `workers` > 64: only wastes threads.
  workersExcessive(ValidationSeverity.warning),

  /// `io_timeout` ≤ 0 or infinite: every HID++ request times out.
  ioTimeoutInvalid(ValidationSeverity.error),

  /// `io_timeout` outside 50–10000 ms: devices may fail or hang.
  ioTimeoutUnusual(ValidationSeverity.warning),

  // ---- device ---------------------------------------------------------
  /// `default_profile` names no profile: logid creates an empty one and the
  /// device starts unconfigured (Device.cpp `_init`).
  defaultProfileUndefined(ValidationSeverity.error),

  /// No capabilities known for this device name (not detected / not in the
  /// device database); device-specific checks were skipped.
  deviceCapabilitiesUnknown(ValidationSeverity.info),

  // ---- dpi ------------------------------------------------------------
  /// `dpi: 0` leaves the DPI unchanged.
  dpiUnchanged(ValidationSeverity.info),

  /// Outside 0–65535: logid truncates to 16 bits (params: effective).
  dpiWraps(ValidationSeverity.error),

  /// Outside the sensor range: clamped (params: effective).
  dpiClamped(ValidationSeverity.warning),

  /// Not a valid step: rounded (params: effective).
  dpiRounded(ValidationSeverity.warning),

  /// Per-sensor list with more (or zero) entries than sensors: logid asks
  /// the device for sensors that do not exist (DPI::_fillDPILists) and then
  /// gives up on the whole device — "Error adding device: Device timed out",
  /// no setting applied (confirmed on an MX Master 3S, Nexo spike S6).
  dpiSensorMismatch(ValidationSeverity.error),

  // ---- smartshift -----------------------------------------------------
  /// Device without SmartShift.
  smartShiftUnsupported(ValidationSeverity.warning),

  /// `threshold: 0` is changed to 1 by logid.
  smartShiftThresholdRaised(ValidationSeverity.warning),

  /// `threshold` > 255 is truncated to 8 bits (params: effective).
  smartShiftThresholdWraps(ValidationSeverity.error),

  /// `torque` on a device without torque support: ignored.
  smartShiftTorqueUnsupported(ValidationSeverity.warning),

  /// `torque` outside 1–100: logid clamps it (params: effective).
  smartShiftTorqueClamped(ValidationSeverity.warning),

  // ---- main wheel -----------------------------------------------------
  /// Device without hi-res wheel.
  hiresScrollUnsupported(ValidationSeverity.warning),

  /// `up`/`down` without `target: true` never fire.
  scrollGesturesWithoutTarget(ValidationSeverity.warning),

  /// `target: true` with neither `up` nor `down`: the wheel stops scrolling
  /// (HiresScroll::_handleScroll has no default).
  scrollWheelDisabled(ValidationSeverity.error),

  /// `target: true` with only one of `up`/`down`: that direction does
  /// nothing (params: direction).
  scrollDirectionDisabled(ValidationSeverity.warning),

  // ---- thumb wheel ----------------------------------------------------
  /// Device without thumb wheel.
  thumbWheelUnsupported(ValidationSeverity.warning),

  /// Gestures/actions without `divert: true` never fire
  /// (ThumbWheel::configure uses `divert.value_or(false)`).
  thumbWheelNotDiverted(ValidationSeverity.warning),

  /// `tap`/`touch`/`proxy` the device cannot sense (params: field).
  thumbWheelFieldUnsupported(ValidationSeverity.warning),

  // ---- buttons --------------------------------------------------------
  /// The device has no control with this CID: ignored silently
  /// (RemapButton only maps the device's own controls).
  buttonNotOnDevice(ValidationSeverity.error),

  /// The control cannot be diverted.
  buttonNotRemappable(ValidationSeverity.error),

  /// Gestures on a control without raw XY: only `None` can work
  /// ("Cannot divert raw XY movements" in RemapButton.cpp).
  buttonGesturesUnsupported(ValidationSeverity.error),

  /// A button entry without action.
  buttonUnmapped(ValidationSeverity.info),

  // ---- actions --------------------------------------------------------
  /// Keypress without keys does nothing.
  keypressWithoutKeys(ValidationSeverity.warning),

  /// Unknown key name: logid logs "Invalid keycode" and skips only that key,
  /// so a shortcut silently loses a key (params: key).
  keyNameUnknown(ValidationSeverity.error),

  /// Key code ≥ KEY_CNT (768): never registered (params: code).
  keyCodeOutOfRange(ValidationSeverity.error),

  /// CycleDPI is broken in logid ≤ 0.3.5: it acts only when the list is
  /// empty, and then walks past the end of it (CycleDPI::press tests
  /// `empty()` instead of `!empty()`; logiops issues #394, #423). Pressing
  /// the button never changes the DPI (confirmed, Nexo spike S6).
  cycleDpiBroken(ValidationSeverity.error),

  /// ChangeDPI without (or with zero) increment does nothing.
  changeDpiNoOp(ValidationSeverity.warning),

  /// `sensor` the device does not have (params: sensor).
  dpiSensorInvalid(ValidationSeverity.error),

  /// ChangeHost without host does nothing.
  changeHostMissing(ValidationSeverity.warning),

  /// Keyword other than next/prev/previous: no channel change (params: host).
  changeHostKeywordUnknown(ValidationSeverity.warning),

  /// Channel < 1 does nothing; above the channel count it wraps around
  /// (ChangeHostAction::release) (params: host, effective).
  changeHostOutOfRange(ValidationSeverity.warning),

  /// "prev" does nothing on channel 1 (logid computes -1 → error).
  changeHostPrevOnFirst(ValidationSeverity.info),

  /// Easy-Switch from a button needs several presses over Bluetooth
  /// (observed on the MX Master 3S, Nexo spike S5).
  changeHostUnreliable(ValidationSeverity.info),

  /// ChangeProfile without profile does nothing.
  changeProfileMissing(ValidationSeverity.warning),

  /// ChangeProfile to a profile that does not exist: logid creates an empty
  /// one and switches to it (Device::setProfile) (params: profile).
  changeProfileUndefined(ValidationSeverity.error),

  /// ChangeProfile to the profile it belongs to.
  changeProfileToSelf(ValidationSeverity.info),

  /// A Gestures action without gestures: the button does nothing.
  gesturesEmpty(ValidationSeverity.warning),

  /// Direction other than Up/Down/Left/Right/None: logid logs
  /// "is not a direction" and drops it (params: direction).
  gestureDirectionInvalid(ValidationSeverity.error),

  /// No `None` gesture: pressing without moving does nothing.
  gesturesWithoutNone(ValidationSeverity.info),

  /// `threshold` on the `None` gesture is forced to 0 by logid.
  gestureNoneThresholdIgnored(ValidationSeverity.info),

  // ---- gestures -------------------------------------------------------
  /// OnInterval/OnFewPixels without `interval` never fire.
  intervalMissing(ValidationSeverity.error),

  /// `interval: 0` divides by zero and kills logid (SIGFPE) as soon as the
  /// gesture moves (IntervalGesture::move; confirmed, Nexo spike S6).
  intervalZero(ValidationSeverity.error),

  /// Negative `interval` never fires.
  intervalNegative(ValidationSeverity.error),

  /// Gesture without action does nothing.
  gestureWithoutAction(ValidationSeverity.warning),

  /// Negative `threshold`: fires on any movement.
  gestureThresholdNegative(ValidationSeverity.warning),

  /// Axis gesture without axis does nothing.
  axisMissing(ValidationSeverity.warning),

  /// Unknown axis name: the gesture does nothing and logid's warning calls
  /// printf without its argument — undefined behaviour that printed random
  /// memory in Nexo spike S6 and may crash (AxisGesture ctor) (params: axis).
  axisNameUnknown(ValidationSeverity.error),

  /// Axis code ≥ REL_CNT (16) (params: code).
  axisCodeOutOfRange(ValidationSeverity.error),

  /// `axis_multiplier: 0` makes the gesture do nothing.
  axisMultiplierZero(ValidationSeverity.warning);

  const ValidationCode(this.severity);

  /// Severity of this rule.
  final ValidationSeverity severity;
}

/// One finding.
final class ValidationIssue {
  /// Creates an issue.
  const ValidationIssue(
    this.code,
    this.path,
    this.message, [
    this.params = const {},
  ]);

  /// The rule.
  final ValidationCode code;

  /// Severity (from [code]).
  ValidationSeverity get severity => code.severity;

  /// Location in the model, e.g.
  /// `devices["MX Master 3S"].profiles["default"].buttons[0xc3].action`.
  final String path;

  /// English description, for logs.
  final String message;

  /// Values for translated messages (e.g. `effective`).
  final Map<String, Object> params;

  @override
  String toString() => '${severity.name} ${code.name} at $path: $message';
}

/// `KEY_CNT` from linux/input-event-codes.h.
const evdevKeyCount = keyMax + 1;

/// `REL_CNT` from linux/input-event-codes.h.
const evdevRelativeAxisCount = relMax + 1;

/// Validates [config]. [devices] maps HID++ device names to what they
/// support (unknown devices skip device-specific checks); [evdev] resolves
/// key and axis names — use `EvdevCatalog.system()` to get exactly the
/// names the installed libevdev (hence logid) accepts.
List<ValidationIssue> validateLogidConfig(
  LogidConfig config, {
  required EvdevCatalog evdev,
  Map<String, LogidDeviceCapabilities> devices = const {},
}) {
  final v = _Validator(evdev);
  v.global(config);
  for (final d in config.devices ?? const <DeviceConfig>[]) {
    v.device(d, devices[d.name], checkCapabilities: devices.isNotEmpty);
  }
  return List.unmodifiable(v.issues);
}

final class _Validator {
  _Validator(this.evdev);

  final EvdevCatalog evdev;
  final issues = <ValidationIssue>[];

  void _add(
    ValidationCode code,
    String path,
    String message, [
    Map<String, Object> params = const {},
  ]) => issues.add(ValidationIssue(code, path, message, params));

  // ---- global -------------------------------------------------------------

  void global(LogidConfig c) {
    final workers = c.workers;
    if (workers != null && workers < 1) {
      _add(
        ValidationCode.workersInvalid,
        'workers',
        'logid starts no worker thread',
      );
    } else if (workers != null && workers > 64) {
      _add(
        ValidationCode.workersExcessive,
        'workers',
        '$workers threads is excessive',
      );
    }
    final timeout = c.ioTimeout;
    if (timeout != null && (timeout <= 0 || timeout.isInfinite)) {
      _add(
        ValidationCode.ioTimeoutInvalid,
        'io_timeout',
        'every request would time out',
      );
    } else if (timeout != null && (timeout < 50 || timeout > 10000)) {
      _add(
        ValidationCode.ioTimeoutUnusual,
        'io_timeout',
        '$timeout ms is unusual (default 500)',
      );
    }
  }

  // ---- device -------------------------------------------------------------

  void device(
    DeviceConfig d,
    LogidDeviceCapabilities? caps, {
    required bool checkCapabilities,
  }) {
    final devicePath = 'devices["${d.name}"]';
    if (d.profile(d.defaultProfile) == null) {
      _add(
        ValidationCode.defaultProfileUndefined,
        '$devicePath.default_profile',
        'profile "${d.defaultProfile}" does not exist; logid starts with an empty profile',
        {'profile': d.defaultProfile},
      );
    }
    if (caps == null && checkCapabilities) {
      _add(
        ValidationCode.deviceCapabilitiesUnknown,
        devicePath,
        'capabilities of "${d.name}" are unknown; device checks skipped',
      );
    }
    for (final p in d.profiles) {
      _Profile(this, d, p, caps, '$devicePath.profiles["${p.name}"]').run();
    }
  }
}

/// Validation of one profile.
final class _Profile {
  _Profile(this.v, this.device, this.profile, this.caps, this.path);

  final _Validator v;
  final DeviceConfig device;
  final Profile profile;
  final LogidDeviceCapabilities? caps;
  final String path;

  void _add(
    ValidationCode code,
    String at,
    String message, [
    Map<String, Object> params = const {},
  ]) => v._add(code, at, message, params);

  void run() {
    _dpi();
    _smartShift();
    _hiresScroll();
    _thumbWheel();
    for (final b in profile.buttons ?? const <ButtonConfig>[]) {
      _button(b);
    }
  }

  // ---- dpi ----------------------------------------------------------------

  void _dpi() {
    final dpi = profile.dpi;
    final at = '$path.dpi';
    switch (dpi) {
      case null:
        return;
      case FixedDpi(:final value):
        _checkDpiValue(value, 0, at);
      case PerSensorDpi(:final values):
        final sensors = caps?.dpiSensors?.length;
        // DPI::configure calls _fillDPILists(dpis.size() - 1): an empty list
        // underflows to sensor 255, a longer list asks for missing sensors.
        if (values.isEmpty || (sensors != null && values.length > sensors)) {
          _add(
            ValidationCode.dpiSensorMismatch,
            at,
            '${values.length} DPI value(s) for ${sensors ?? 'unknown'} '
            'sensor(s); logid gives up on the device and applies nothing',
            {'values': values.length, 'sensors': ?sensors},
          );
        }
        for (var i = 0; i < values.length; i++) {
          _checkDpiValue(values[i], i, '$at[$i]');
        }
    }
  }

  void _checkDpiValue(int value, int sensor, String at) {
    if (value == 0) {
      _add(ValidationCode.dpiUnchanged, at, 'dpi 0 leaves the DPI unchanged');
      return;
    }
    final capability =
        caps?.dpiSensors != null && sensor < caps!.dpiSensors!.length
        ? caps!.dpiSensors![sensor]
        : null;
    final truncated = value & 0xFFFF;
    if (truncated != value) {
      final effective = capability == null
          ? truncated
          : effectiveDpi(value, capability)!;
      _add(
        ValidationCode.dpiWraps,
        at,
        '$value does not fit 16 bits; logid uses $effective',
        {'value': value, 'effective': effective},
      );
      return;
    }
    if (capability == null) return;
    final effective = effectiveDpi(value, capability)!;
    if (effective == value) return;
    final outside = switch (capability) {
      DpiRange(:final min, :final max) => value < min || value > max,
      DpiList() => true,
    };
    _add(
      outside ? ValidationCode.dpiClamped : ValidationCode.dpiRounded,
      at,
      'logid sets $effective instead of $value',
      {'value': value, 'effective': effective},
    );
  }

  // ---- smartshift ---------------------------------------------------------

  void _smartShift() {
    final s = profile.smartShift;
    if (s == null) return;
    final at = '$path.smartshift';
    if (caps?.smartShift == false) {
      _add(
        ValidationCode.smartShiftUnsupported,
        at,
        'the device has no SmartShift',
      );
    }
    final threshold = s.threshold;
    if (threshold == 0) {
      _add(
        ValidationCode.smartShiftThresholdRaised,
        '$at.threshold',
        'logid changes 0 to 1',
      );
    } else if (threshold != null && threshold > 255) {
      final effective = threshold & 0xFF;
      _add(
        ValidationCode.smartShiftThresholdWraps,
        '$at.threshold',
        '$threshold is sent as $effective (8 bits)',
        {'value': threshold, 'effective': effective},
      );
    }
    final torque = s.torque;
    if (torque != null) {
      if (caps?.torque == false) {
        _add(
          ValidationCode.smartShiftTorqueUnsupported,
          '$at.torque',
          'the device ignores torque',
        );
      }
      if (torque == 0 || torque > 100) {
        final effective = torque == 0 ? 1 : 100;
        _add(
          ValidationCode.smartShiftTorqueClamped,
          '$at.torque',
          'logid uses $effective',
          {'value': torque, 'effective': effective},
        );
      }
    }
  }

  // ---- main wheel ----------------------------------------------------------

  void _hiresScroll() {
    final h = profile.hiresScroll;
    if (h == null) return;
    final at = '$path.hiresscroll';
    if (caps?.hiresScroll == false) {
      _add(
        ValidationCode.hiresScrollUnsupported,
        at,
        'the device has no hi-res wheel',
      );
    }
    if (h.target == true) {
      if (h.up == null && h.down == null) {
        _add(
          ValidationCode.scrollWheelDisabled,
          '$at.target',
          'the wheel stops scrolling',
        );
      } else if (h.up == null || h.down == null) {
        final dead = h.up == null ? 'up' : 'down';
        _add(
          ValidationCode.scrollDirectionDisabled,
          '$at.$dead',
          'scrolling $dead does nothing',
          {'direction': dead},
        );
      }
    } else if (h.up != null || h.down != null) {
      _add(
        ValidationCode.scrollGesturesWithoutTarget,
        '$at.target',
        'up/down gestures need target: true',
      );
    }
    if (h.up != null) _gesture(h.up!, '$at.up');
    if (h.down != null) _gesture(h.down!, '$at.down');
  }

  // ---- thumb wheel --------------------------------------------------------

  void _thumbWheel() {
    final t = profile.thumbWheel;
    if (t == null) return;
    final at = '$path.thumbwheel';
    if (caps?.thumbWheel == false) {
      _add(
        ValidationCode.thumbWheelUnsupported,
        at,
        'the device has no thumb wheel',
      );
    }
    final usesEvents =
        t.left != null ||
        t.right != null ||
        t.tap != null ||
        t.touch != null ||
        t.proxy != null;
    if (usesEvents && t.divert != true) {
      _add(
        ValidationCode.thumbWheelNotDiverted,
        '$at.divert',
        'actions need divert: true',
      );
    }
    for (final (field, supported, action) in [
      ('tap', caps?.thumbWheelTap, t.tap),
      ('touch', caps?.thumbWheelTouch, t.touch),
      ('proxy', caps?.thumbWheelProxy, t.proxy),
    ]) {
      if (action == null) continue;
      if (supported == false) {
        _add(
          ValidationCode.thumbWheelFieldUnsupported,
          '$at.$field',
          'the thumb wheel cannot sense $field',
          {'field': field},
        );
      }
      _action(action, '$at.$field');
    }
    if (t.left != null) _gesture(t.left!, '$at.left');
    if (t.right != null) _gesture(t.right!, '$at.right');
  }

  // ---- buttons ------------------------------------------------------------

  void _button(ButtonConfig b) {
    final at = '$path.buttons[0x${b.cid.toRadixString(16)}]';
    final buttonCaps = caps?.buttons;
    if (buttonCaps != null) {
      final cap = caps!.button(b.cid);
      if (cap == null) {
        _add(
          ValidationCode.buttonNotOnDevice,
          at,
          'the device has no control 0x${b.cid.toRadixString(16)}; logid ignores it',
          {'cid': b.cid},
        );
      } else if (!cap.remappable) {
        _add(
          ValidationCode.buttonNotRemappable,
          at,
          'this control cannot be remapped',
          {'cid': b.cid},
        );
      } else if (b.action is GesturesAction && !cap.gestureSupport) {
        _add(
          ValidationCode.buttonGesturesUnsupported,
          '$at.action',
          'this control cannot track movement; only None can work',
          {'cid': b.cid},
        );
      }
    }
    final action = b.action;
    if (action == null) {
      _add(ValidationCode.buttonUnmapped, at, 'no action');
    } else {
      _action(action, '$at.action');
    }
  }

  // ---- actions ----------------------------------------------------------------

  void _action(LogidAction action, String at) {
    switch (action) {
      case NoneAction() ||
          ToggleSmartShiftAction() ||
          ToggleHiresScrollAction():
        return;
      case KeypressAction(:final keys):
        _keys(keys, at);
      case CycleDpiAction(:final dpis, :final sensor):
        _add(
          ValidationCode.cycleDpiBroken,
          at,
          'CycleDPI does not work in logid 0.3.5'
          '${dpis == null || dpis.isEmpty ? ' and an empty list may crash it' : ''}',
        );
        _sensor(sensor, '$at.sensor');
      case ChangeDpiAction(:final inc, :final sensor):
        if (inc == null || inc == 0) {
          _add(ValidationCode.changeDpiNoOp, '$at.inc', 'no increment');
        }
        _sensor(sensor, '$at.sensor');
      case ChangeHostAction(:final host):
        _changeHost(host, at);
      case ChangeProfileAction(:final profile):
        _changeProfile(profile, at);
      case GesturesAction(:final gestures):
        _gestures(gestures, at);
    }
  }

  void _keys(List<KeyRef>? keys, String at) {
    if (keys == null || keys.isEmpty) {
      _add(ValidationCode.keypressWithoutKeys, '$at.keys', 'no keys');
      return;
    }
    for (var i = 0; i < keys.length; i++) {
      switch (keys[i]) {
        case KeyName(:final name):
          if (v.evdev.keyCode(name) == null) {
            _add(
              ValidationCode.keyNameUnknown,
              '$at.keys[$i]',
              '"$name" is not a key name; logid skips it',
              {'key': name},
            );
          }
        case KeyCode(:final code):
          if (code >= evdevKeyCount) {
            _add(
              ValidationCode.keyCodeOutOfRange,
              '$at.keys[$i]',
              'key code $code does not exist',
              {'code': code},
            );
          }
      }
    }
  }

  void _sensor(int? sensor, String at) {
    final sensors = caps?.dpiSensors?.length;
    if (sensor == null || sensors == null) return;
    if (sensor < 0 || sensor >= sensors) {
      _add(
        ValidationCode.dpiSensorInvalid,
        at,
        'the device has $sensors DPI sensor(s)',
        {'sensor': sensor, 'sensors': sensors},
      );
    }
  }

  void _changeHost(HostTarget? host, String at) {
    _add(
      ValidationCode.changeHostUnreliable,
      at,
      'may need several presses over Bluetooth',
    );
    switch (host) {
      case null:
        _add(ValidationCode.changeHostMissing, '$at.host', 'no host');
      case HostKeyword(:final keyword):
        final k = asciiLowerCase(keyword);
        if (k == 'prev' || k == 'previous') {
          _add(
            ValidationCode.changeHostPrevOnFirst,
            '$at.host',
            '"prev" does nothing on channel 1',
          );
        } else if (k != 'next') {
          _add(
            ValidationCode.changeHostKeywordUnknown,
            '$at.host',
            '"$keyword" is not next/prev; nothing happens',
            {'host': keyword},
          );
        }
      case HostNumber(:final number):
        final count = caps?.hostCount;
        if (number >= 1 && (count == null || number <= count)) return;
        // ChangeHostAction::release: next = (number - 1) % count with C++
        // semantics (sign of the dividend); a negative result becomes
        // uint8 ≥ 128 and setHost throws, so nothing happens.
        final r = count == null ? null : (number - 1).remainder(count);
        final effective = r == null || r < 0 ? null : r + 1;
        _add(
          ValidationCode.changeHostOutOfRange,
          '$at.host',
          effective == null
              ? 'channel $number does nothing'
              : 'channel $number goes to channel $effective',
          {'host': number, 'effective': ?effective},
        );
    }
  }

  void _changeProfile(String? target, String at) {
    if (target == null) {
      _add(ValidationCode.changeProfileMissing, '$at.profile', 'no profile');
    } else if (device.profile(target) == null) {
      _add(
        ValidationCode.changeProfileUndefined,
        '$at.profile',
        'profile "$target" does not exist; logid would switch to an empty profile',
        {'profile': target},
      );
    } else if (target == profile.name) {
      _add(
        ValidationCode.changeProfileToSelf,
        '$at.profile',
        'already in "$target"',
      );
    }
  }

  static const _directions = {'up', 'down', 'left', 'right', 'none'};

  void _gestures(List<DirectionalGesture>? gestures, String at) {
    if (gestures == null || gestures.isEmpty) {
      _add(ValidationCode.gesturesEmpty, '$at.gestures', 'no gestures');
      return;
    }
    var hasNone = false;
    for (final g in gestures) {
      final direction = asciiLowerCase(g.direction);
      final gAt = '$at.gestures["${g.direction}"]';
      if (!_directions.contains(direction)) {
        _add(
          ValidationCode.gestureDirectionInvalid,
          gAt,
          '"${g.direction}" is not a direction; logid drops it',
          {'direction': g.direction},
        );
        continue;
      }
      if (direction == 'none') {
        hasNone = true;
        if (g.gesture.threshold != null && g.gesture.threshold != 0) {
          _add(
            ValidationCode.gestureNoneThresholdIgnored,
            '$gAt.threshold',
            'forced to 0 by logid',
          );
        }
      }
      _gesture(g.gesture, gAt);
    }
    if (!hasNone) {
      _add(
        ValidationCode.gesturesWithoutNone,
        '$at.gestures',
        'pressing without moving does nothing',
      );
    }
  }

  // ---- gestures ---------------------------------------------------------------

  void _gesture(Gesture g, String at) {
    final threshold = g.threshold;
    if (threshold != null && threshold < 0) {
      _add(
        ValidationCode.gestureThresholdNegative,
        '$at.threshold',
        'fires on any movement',
      );
    }
    switch (g) {
      case NoPressGesture():
        return;
      case AxisGesture(:final axis, :final axisMultiplier):
        switch (axis) {
          case null:
            _add(ValidationCode.axisMissing, '$at.axis', 'no axis');
          case AxisName(:final name):
            if (v.evdev.relativeAxisCode(name) == null) {
              _add(
                ValidationCode.axisNameUnknown,
                '$at.axis',
                '"$name" is not an axis; the gesture does nothing and logid '
                    'may crash',
                {'axis': name},
              );
            }
          case AxisCode(:final code):
            if (code >= evdevRelativeAxisCount) {
              _add(
                ValidationCode.axisCodeOutOfRange,
                '$at.axis',
                'axis code $code does not exist',
                {'code': code},
              );
            }
        }
        if (axisMultiplier == 0) {
          _add(
            ValidationCode.axisMultiplierZero,
            '$at.axis_multiplier',
            'no movement',
          );
        }
      case IntervalGesture(:final interval, :final action):
        if (interval == null) {
          _add(
            ValidationCode.intervalMissing,
            '$at.interval',
            'never fires without interval',
          );
        } else if (interval == 0) {
          _add(
            ValidationCode.intervalZero,
            '$at.interval',
            'crashes logid (division by zero)',
          );
        } else if (interval < 0) {
          _add(ValidationCode.intervalNegative, '$at.interval', 'never fires');
        }
        _gestureAction(action, at);
      case ReleaseGesture(:final action) || ThresholdGesture(:final action):
        _gestureAction(action, at);
    }
  }

  void _gestureAction(BasicAction? action, String at) {
    if (action == null) {
      _add(ValidationCode.gestureWithoutAction, '$at.action', 'no action');
    } else {
      _action(action, '$at.action');
    }
  }
}
