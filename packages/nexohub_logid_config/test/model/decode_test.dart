// Documents each decoding rule with the issue code the UI receives. Fidelity
// to logid itself is enforced by differential_test.dart.
import 'dart:io';

import 'package:nexohub_logid_config/nexohub_logid_config.dart';
import 'package:test/test.dart';

DecodeResult decode(String text) => parseLogidConfig(text);

Profile flatProfile(String deviceBody) =>
    decode('devices: ({ name: "M"; $deviceBody });')
        .config
        .devices!
        .single
        .profiles
        .single;

List<DecodeIssueCode> codes(DecodeResult r) => [
  for (final i in r.issues) i.code,
];

void main() {
  group("the user's original configuration", () {
    final text = File('../../fixtures/logid/user-original-2026-10-27.cfg')
        .readAsStringSync();

    test('decodes without any issue into the expected model', () {
      final result = decode(text);
      expect(result.issues, isEmpty);
      final device = result.config.device('MX Master 3S')!;
      expect(device.isFlat, isTrue);
      final p = device.profiles.single;
      expect(p.name, 'default');
      expect(p.dpi, FixedDpi(1600));
      expect(p.smartShift, SmartShiftConfig(on: true, threshold: 20));
      expect(
        p.hiresScroll,
        HiresScrollConfig(hires: false, invert: false, target: false),
      );
      expect(
        p.thumbWheel!.left,
        IntervalGesture(
          interval: 3,
          action: KeypressAction(
            keys: const [
              KeyName('KEY_LEFTCTRL'),
              KeyName('KEY_LEFTSHIFT'),
              KeyName('KEY_TAB'), //
            ],
          ),
        ),
      );
      final gestures = p.button(0xc3)!.action! as GesturesAction;
      expect(gestures.gestures!.map((g) => g.direction), [
        'None',
        'Up',
        'Down',
        'Left',
        'Right',
      ]);
      expect(
        gestures.gesture('up')!.gesture,
        ReleaseGesture(
          action: KeypressAction(
            keys: const [KeyName('KEY_LEFTMETA'), KeyName('KEY_S')],
          ),
        ),
      );
      expect(p.button(0xc4)!.action, ToggleSmartShiftAction());
    });

    test('is rewritten exactly as the canonical golden file', () {
      final golden = File(
        '../../fixtures/logid/user-original-2026-10-27.canonical.cfg',
      ).readAsStringSync();
      expect(
        writeLogidConfig(decode(text).config, header: 'Managed by Nexo'),
        golden,
      );
    });
  });

  group('strict scalar types (fieldIgnored: logid logs and ignores)', () {
    test('a float threshold is ignored', () {
      final r = decode(
        'devices: ({ name: "M"; smartshift: { on: true; threshold: 20.0; }; });',
      );
      expect(
        r.config.devices!.single.profiles.single.smartShift,
        SmartShiftConfig(on: true),
      );
      expect(codes(r), [DecodeIssueCode.fieldIgnored]);
      expect(r.issues.single.loggedByLogid, isTrue);
      expect(r.issues.single.path, r'$.devices[0].smartshift.threshold');
    });

    test('io_timeout must be a float', () {
      final r = decode('io_timeout = 500;');
      expect(r.config.ioTimeout, isNull);
      expect(codes(r), [DecodeIssueCode.fieldIgnored]);
      expect(decode('io_timeout = 500.0;').config.ioTimeout, 500.0);
    });

    test('an unknown action type ignores the whole action', () {
      final r = decode(
        'devices: ({ name: "M"; buttons: ({ cid: 0xc3; action: { type: "Bogus"; }; }); });',
      );
      expect(
        r.config.devices!.single.profiles.single.button(0xc3)!.action,
        isNull,
      );
      expect(codes(r), [DecodeIssueCode.fieldIgnored]);
    });

    test('Gestures is not allowed outside buttons', () {
      final r = decode(
        'devices: ({ name: "M"; thumbwheel: { tap: { type: "Gestures"; }; }; });',
      );
      expect(r.config.devices!.single.profiles.single.thumbWheel!.tap, isNull);
      expect(codes(r), [DecodeIssueCode.fieldIgnored]);
    });
  });

  group('values logid reinterprets', () {
    test('a non-int dpi becomes an empty per-sensor list (no effect)', () {
      expect(flatProfile('dpi: 1600L;').dpi, PerSensorDpi(const []));
      expect(
        flatProfile('dpi: [800, 1600];').dpi,
        PerSensorDpi(const [800, 1600]),
      );
    });

    test('cid is truncated to 16 bits', () {
      final r = decode(
        'devices: ({ name: "M"; buttons: ({ cid: 0x100c4; }); });',
      );
      expect(
        r.config.devices!.single.profiles.single.buttons!.single.cid,
        0xc4,
      );
      expect(codes(r), [DecodeIssueCode.valueReinterpreted]);
    });

    test('negative SmartShift threshold becomes a huge unsigned value', () {
      expect(
        flatProfile('smartshift: { threshold: -1; };').smartShift!.threshold,
        0xFFFFFFFF,
      );
    });

    test('a non-group smartshift is an empty group', () {
      final r = decode('devices: ({ name: "M"; smartshift: 5; });');
      expect(
        r.config.devices!.single.profiles.single.smartShift,
        SmartShiftConfig(),
      );
      expect(codes(r), [DecodeIssueCode.valueReinterpreted]);
    });

    test('hiresscroll: true sets only the hires flag', () {
      expect(
        flatProfile('hiresscroll: true;').hiresScroll,
        HiresScrollConfig(hires: true),
      );
    });

    test('single keys become a one-element list; bad elements are dropped', () {
      final keys =
          (flatProfile(
                    'buttons: ({ cid: 0xc3; action: { type: "Keypress"; keys: ("KEY_A", 30, 1.5); }; });',
                  ).button(0xc3)!.action!
                  as KeypressAction)
              .keys;
      expect(keys, [const KeyName('KEY_A'), KeyCode(30)]);
    });

    test('type and mode are ASCII case-insensitive (Kelvin sign is not K)', () {
      expect(
        flatProfile('buttons: ({ cid: 1; action: { type: "kEyPrEsS"; }; });')
            .button(1)!
            .action,
        KeypressAction(),
      );
      final r = decode(
        'devices: ({ name: "M"; buttons: ({ cid: 1; action: { type: "Keypress"; }; }); });',
      );
      expect(codes(r), [DecodeIssueCode.fieldIgnored]);
    });
  });

  group('collections (first key wins, invalid elements dropped silently)', () {
    test('duplicate cid keeps the first; the later one is still decoded', () {
      final r = decode(
        'devices: ({ name: "M"; buttons: ({ cid: 0xc3; action: { type: "None"; }; }, '
        '{ cid: 0xc3; action: { type: "Bogus"; }; }); });',
      );
      expect(
        r.config.devices!.single.profiles.single.button(0xc3)!.action,
        NoneAction(),
      );
      expect(codes(r), [
        DecodeIssueCode.fieldIgnored,
        DecodeIssueCode.duplicateIgnored,
      ]);
    });

    test('gesture directions are unique ignoring case', () {
      final r = decode(
        'devices: ({ name: "M"; buttons: ({ cid: 1; action: { type: "Gestures"; gestures: ('
        '{ direction: "Up"; mode: "NoPress"; }, { direction: "up"; mode: "OnRelease"; }); }; }); });',
      );
      final g =
          r.config.devices!.single.profiles.single.button(1)!.action!
              as GesturesAction;
      expect(g.gestures!.single.gesture, NoPressGesture());
      expect(codes(r), [DecodeIssueCode.duplicateIgnored]);
    });

    test('a button without cid or a gesture with a bad mode is dropped', () {
      final r = decode(
        'devices: ({ name: "M"; buttons: ({ action: { type: "None"; }; }, '
        '{ cid: 1; action: { type: "Gestures"; gestures: ({ direction: "Up"; mode: "Bogus"; }); }; }); });',
      );
      expect(codes(r), [
        DecodeIssueCode.elementIgnored,
        DecodeIssueCode.elementIgnored,
      ]);
    });
  });

  group('device forms', () {
    test('profiles without default_profile are all ignored', () {
      final r = decode(
        'devices: ({ name: "M"; profiles: ({ name: "p"; dpi: 800; }); dpi: 400; });',
      );
      final d = r.config.devices!.single;
      expect(d.isFlat, isTrue);
      expect(d.profiles.single.dpi, FixedDpi(400));
      expect(codes(r), contains(DecodeIssueCode.profilesIgnored));
    });

    test('profile form; device-level profile fields are ignored', () {
      final r = decode(
        'devices: ({ name: "M"; default_profile: "p"; profiles: ({ name: "p"; dpi: 800; }, { name: "q"; }); dpi: 400; });',
      );
      final d = r.config.devices!.single;
      expect(d.defaultProfile, 'p');
      expect(d.profiles.map((p) => p.name), ['p', 'q']);
      expect(d.profile('p')!.dpi, FixedDpi(800));
      expect(codes(r), [DecodeIssueCode.keyIgnored]);
    });

    test('no valid profile falls back to an empty "default"', () {
      final r = decode(
        'devices: ({ name: "M"; default_profile: "p"; profiles: (); });',
      );
      final d = r.config.devices!.single;
      expect(
        (d.defaultProfile, d.profiles.single),
        ('default', Profile(name: 'default')),
      );
      expect(codes(r), [DecodeIssueCode.valueReinterpreted]);
    });
  });

  group('unknown keys', () {
    test('are preserved and written back', () {
      final r = decode(
        'my_note = "x"; devices: ({ name: "M"; foo: 1; smartshift: { bar: 2; }; });',
      );
      expect(codes(r), everyElement(DecodeIssueCode.unknownKey));
      expect(r.issues.every((i) => !i.changesOnSave), isTrue);
      final again = parseLogidConfig(writeLogidConfig(r.config));
      expect(again.config, r.config);
    });
  });
}
