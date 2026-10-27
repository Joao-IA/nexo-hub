import 'dart:io';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';
import 'package:test/test.dart';

import '../support/devices.dart';
import '../support/model_generators.dart';

const _evdev = FakeEvdevNames();

List<ValidationIssue> check(
  String deviceBody, {
  String top = '',
  bool withCaps = true,
}) {
  final config = parseLogidConfig(
    '$top devices: ({ name: "MX Master 3S"; $deviceBody });',
  ).config;
  return validateLogidConfig(
    config,
    evdev: _evdev,
    devices: withCaps ? const {'MX Master 3S': mxMaster3s} : const {},
  );
}

List<ValidationCode> codes(List<ValidationIssue> issues) => [
  for (final i in issues) i.code,
];

String button(int cid, String action) =>
    'buttons: ({ cid: $cid; action: $action; });';

void main() {
  test("the user's original configuration has no findings at all", () {
    final config = parseLogidConfig(
      File('../../fixtures/logid/user-original-2026-10-27.cfg')
          .readAsStringSync(),
    ).config;
    expect(
      validateLogidConfig(
        config,
        evdev: _evdev,
        devices: const {'MX Master 3S': mxMaster3s},
      ),
      isEmpty,
    );
  });

  group('global', () {
    test('workers and io_timeout', () {
      expect(codes(check('', top: 'workers = 0;')), [
        ValidationCode.workersInvalid,
      ]);
      expect(codes(check('', top: 'workers = 200;')), [
        ValidationCode.workersExcessive,
      ]);
      expect(codes(check('', top: 'io_timeout = 0.0;')), [
        ValidationCode.ioTimeoutInvalid,
      ]);
      expect(codes(check('', top: 'io_timeout = 20.0;')), [
        ValidationCode.ioTimeoutUnusual,
      ]);
      expect(check('', top: 'workers = 4; io_timeout = 500.0;'), isEmpty);
    });
  });

  group('device', () {
    test('default_profile must exist', () {
      expect(
        codes(check('default_profile: "x"; profiles: ({ name: "a"; });')),
        [ValidationCode.defaultProfileUndefined],
      );
    });

    test('unknown devices skip device checks but are reported', () {
      final config = parseLogidConfig(
        'devices: ({ name: "Other"; buttons: ({ cid: 0x999; action: { type: "None"; }; }); });',
      ).config;
      expect(
        codes(
          validateLogidConfig(
            config,
            evdev: _evdev,
            devices: const {'MX Master 3S': mxMaster3s},
          ),
        ),
        [ValidationCode.deviceCapabilitiesUnknown],
      );
      expect(validateLogidConfig(config, evdev: _evdev), isEmpty);
    });
  });

  group('dpi', () {
    test('valid, unchanged, rounded, clamped, wrapped', () {
      expect(check('dpi: 1600;'), isEmpty);
      expect(codes(check('dpi: 0;')), [ValidationCode.dpiUnchanged]);
      final rounded = check('dpi: 1625;').single;
      expect(
        (rounded.code, rounded.params['effective']),
        (ValidationCode.dpiRounded, 1650),
      );
      expect(check('dpi: 9000;').single.params['effective'], 8000);
      expect(check('dpi: 100;').single.code, ValidationCode.dpiClamped);
      final wrapped = check('dpi: 70000;').single;
      expect(
        (wrapped.code, wrapped.params['effective']),
        (ValidationCode.dpiWraps, 4450), // 70000 → 4464 (16 bits) → step 4450
      );
    });

    test('per-sensor lists must match the sensor count', () {
      expect(check('dpi: [1600];'), isEmpty);
      expect(codes(check('dpi: [800, 1600];')), [
        ValidationCode.dpiSensorMismatch,
      ]);
      // `dpi: 1600L` decodes as an empty list in logid.
      expect(codes(check('dpi: 1600L;')), [ValidationCode.dpiSensorMismatch]);
    });

    test('effectiveDpi mirrors DPI::getClosestDPI', () {
      const range = DpiRange(min: 200, max: 8000, step: 50);
      expect(effectiveDpi(1600, range), 1600);
      expect(effectiveDpi(1624, range), 1600);
      expect(effectiveDpi(1625, range), 1650); // round half away from zero
      expect(effectiveDpi(-1, range), 8000); // 0xFFFF > max
      expect(effectiveDpi(0, range), isNull);
      const list = DpiList([400, 800, 1600]);
      expect(effectiveDpi(800, list), 800);
      expect(effectiveDpi(1000, list), 1600); // logid picks the largest
    });
  });

  group('smartshift and wheels', () {
    test('smartshift ranges and torque support', () {
      expect(check('smartshift: { on: true; threshold: 20; };'), isEmpty);
      expect(codes(check('smartshift: { threshold: 0; };')), [
        ValidationCode.smartShiftThresholdRaised,
      ]);
      expect(
        check('smartshift: { threshold: 300; };').single.params['effective'],
        44,
      );
      expect(codes(check('smartshift: { torque: 150; };')), [
        ValidationCode.smartShiftTorqueUnsupported,
        ValidationCode.smartShiftTorqueClamped,
      ]);
    });

    test('hiresscroll target and gestures', () {
      const up =
          'up: { mode: "OnInterval"; interval: 1; action: { type: "Keypress"; keys: ["KEY_VOLUMEUP"]; }; };';
      expect(codes(check('hiresscroll: { target: true; };')), [
        ValidationCode.scrollWheelDisabled,
      ]);
      expect(
        check('hiresscroll: { target: true; $up };').single.params['direction'],
        'down',
      );
      expect(codes(check('hiresscroll: { $up };')), [
        ValidationCode.scrollGesturesWithoutTarget,
      ]);
      expect(check('hiresscroll: { hires: false; invert: true; };'), isEmpty);
    });

    test('thumb wheel needs divert', () {
      const left =
          'left: { mode: "OnInterval"; interval: 3; action: { type: "Keypress"; keys: ["KEY_A"]; }; };';
      expect(codes(check('thumbwheel: { $left };')), [
        ValidationCode.thumbWheelNotDiverted,
      ]);
      expect(check('thumbwheel: { divert: true; $left };'), isEmpty);
    });
  });

  group('buttons', () {
    test('device controls', () {
      expect(codes(check(button(0x999, '{ type: "None"; }'))), [
        ValidationCode.buttonNotOnDevice,
      ]);
      expect(codes(check(button(0x50, '{ type: "None"; }'))), [
        ValidationCode.buttonNotRemappable,
      ]);
      expect(codes(check('buttons: ({ cid: 0xc3; });')), [
        ValidationCode.buttonUnmapped,
      ]);
    });

    test('every remappable button of the 3S accepts gestures', () {
      for (final cid in [0x52, 0x53, 0x56, 0xc3, 0xc4, 0xd7]) {
        expect(
          check(
            button(
              cid,
              '{ type: "Gestures"; gestures: ({ direction: "None"; mode: "OnRelease"; action: { type: "None"; }; }); }',
            ),
          ),
          isEmpty,
          reason: 'cid 0x${cid.toRadixString(16)}',
        );
      }
    });
  });

  group('actions', () {
    test('keypress', () {
      expect(codes(check(button(0xc3, '{ type: "Keypress"; }'))), [
        ValidationCode.keypressWithoutKeys,
      ]);
      expect(
        check(
          button(
            0xc3,
            '{ type: "Keypress"; keys: ["KEY_LEFTCTRL", "KEY_SHIFTT"]; }',
          ),
        ).single.params['key'],
        'KEY_SHIFTT',
      );
      expect(codes(check(button(0xc3, '{ type: "Keypress"; keys: 768; }'))), [
        ValidationCode.keyCodeOutOfRange,
      ]);
      expect(
        check(button(0xc3, '{ type: "Keypress"; keys: ("BTN_LEFT", 30); }')),
        isEmpty,
      );
    });

    test('CycleDPI is broken in logid 0.3.5', () {
      expect(
        codes(check(button(0xc4, '{ type: "CycleDPI"; dpis: [800, 1600]; }'))),
        [ValidationCode.cycleDpiBroken],
      );
      expect(
        check(button(0xc4, '{ type: "CycleDPI"; }')).single.message,
        contains('may crash'),
      );
    });

    test('ChangeDPI', () {
      expect(check(button(0xc4, '{ type: "ChangeDPI"; inc: 100; }')), isEmpty);
      expect(
        codes(check(button(0xc4, '{ type: "ChangeDPI"; inc: 0; sensor: 1; }'))),
        [ValidationCode.changeDpiNoOp, ValidationCode.dpiSensorInvalid],
      );
    });

    test('ChangeHost channels and keywords', () {
      List<ValidationCode> host(String h) => [
        for (final c in codes(
          check(button(0x53, '{ type: "ChangeHost"; host: $h; }')),
        ))
          if (c != ValidationCode.changeHostUnreliable) c,
      ];
      expect(host('"next"'), isEmpty);
      expect(host('"Previous"'), [ValidationCode.changeHostPrevOnFirst]);
      expect(host('"other"'), [ValidationCode.changeHostKeywordUnknown]);
      expect(host('2'), isEmpty);
      final wraps = check(button(0x53, '{ type: "ChangeHost"; host: 4; }'))
          .firstWhere((i) => i.code == ValidationCode.changeHostOutOfRange);
      expect(wraps.params['effective'], 1);
      final negative = check(button(0x53, '{ type: "ChangeHost"; host: -2; }'))
          .firstWhere((i) => i.code == ValidationCode.changeHostOutOfRange);
      expect(negative.params['effective'], 1); // (-3) % 3 == 0 in C++
      final zero = check(button(0x53, '{ type: "ChangeHost"; host: 0; }'))
          .firstWhere((i) => i.code == ValidationCode.changeHostOutOfRange);
      expect(zero.params.containsKey('effective'), isFalse);
    });

    test('ChangeProfile must target an existing profile', () {
      const profiles =
          'default_profile: "a"; profiles: ('
          '{ name: "a"; buttons: ({ cid: 0xc4; action: { type: "ChangeProfile"; profile: "%s"; }; }); }, { name: "b"; });';
      expect(check(profiles.replaceAll('%s', 'b')), isEmpty);
      expect(codes(check(profiles.replaceAll('%s', 'c'))), [
        ValidationCode.changeProfileUndefined,
      ]);
      expect(codes(check(profiles.replaceAll('%s', 'a'))), [
        ValidationCode.changeProfileToSelf,
      ]);
    });
  });

  group('gestures', () {
    String gestures(String list) =>
        button(0xc3, '{ type: "Gestures"; gestures: ($list); }');
    const none =
        '{ direction: "None"; mode: "OnRelease"; action: { type: "None"; }; }';

    test('directions', () {
      expect(codes(check(gestures(''))), [ValidationCode.gesturesEmpty]);
      expect(
        codes(
          check(
            gestures(
              '{ direction: "Up"; mode: "OnRelease"; action: { type: "None"; }; }',
            ),
          ),
        ),
        [ValidationCode.gesturesWithoutNone],
      );
      expect(
        codes(
          check(gestures('$none, { direction: "Diagonal"; mode: "NoPress"; }')),
        ),
        [ValidationCode.gestureDirectionInvalid],
      );
      expect(
        codes(
          check(
            gestures(
              '{ direction: "none"; mode: "OnRelease"; threshold: 30; action: { type: "None"; }; }',
            ),
          ),
        ),
        [ValidationCode.gestureNoneThresholdIgnored],
      );
    });

    test('interval rules (0 crashes logid)', () {
      String interval(String v) => gestures(
        '$none, { direction: "Up"; mode: "OnInterval"; $v action: { type: "None"; }; }',
      );
      expect(codes(check(interval(''))), [ValidationCode.intervalMissing]);
      expect(codes(check(interval('interval: 0;'))), [
        ValidationCode.intervalZero,
      ]);
      expect(codes(check(interval('interval: -5;'))), [
        ValidationCode.intervalNegative,
      ]);
      expect(check(interval('interval: 5;')), isEmpty);
    });

    test('actions, thresholds and axes', () {
      expect(
        codes(
          check(gestures('$none, { direction: "Up"; mode: "OnRelease"; }')),
        ),
        [ValidationCode.gestureWithoutAction],
      );
      expect(
        codes(
          check(
            gestures(
              '$none, { direction: "Up"; mode: "NoPress"; threshold: -1; }',
            ),
          ),
        ),
        [ValidationCode.gestureThresholdNegative],
      );
      String axis(String fields) =>
          gestures('$none, { direction: "Up"; mode: "Axis"; $fields }');
      expect(check(axis('axis: "REL_WHEEL"; axis_multiplier: 2.0;')), isEmpty);
      expect(codes(check(axis(''))), [ValidationCode.axisMissing]);
      expect(codes(check(axis('axis: "REL_WHEELL";'))), [
        ValidationCode.axisNameUnknown,
      ]);
      expect(codes(check(axis('axis: 16;'))), [
        ValidationCode.axisCodeOutOfRange,
      ]);
      expect(codes(check(axis('axis: "REL_WHEEL"; axis_multiplier: 0.0;'))), [
        ValidationCode.axisMultiplierZero,
      ]);
    });
  });

  test('issues carry readable paths', () {
    final issue = check(button(0xc3, '{ type: "Keypress"; keys: ["KEY_X"]; }'))
        .single;
    expect(
      issue.path,
      'devices["MX Master 3S"].profiles["default"].buttons[0xc3].action.keys[0]',
    );
    expect(issue.severity, ValidationSeverity.error);
  });

  test(
    'never throws on 5000 decoded mistaken configs and 3000 random models',
    () {
      final trees = LogidTreeGenerator(99);
      final models = ModelGenerator(99);
      for (var i = 0; i < 5000; i++) {
        final c = decodeLogidConfig(trees.document()).config;
        validateLogidConfig(c, evdev: _evdev);
        validateLogidConfig(
          c,
          evdev: _evdev,
          devices: const {
            'MX Master 3S': mxMaster3s,
            'M720': LogidDeviceCapabilities(),
          },
        );
      }
      for (var i = 0; i < 3000; i++) {
        validateLogidConfig(
          models.config(),
          evdev: _evdev,
          devices: const {'MX Master 3S': mxMaster3s},
        );
      }
    },
  );
}
