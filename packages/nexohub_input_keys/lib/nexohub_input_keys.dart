/// Linux input key catalog for Nexo.
///
/// * [EvdevCatalog]: which key/axis names logid accepts — resolved by the
///   system libevdev ([LibevdevCatalog], identical to logid) or by tables
///   generated from it ([TableEvdevCatalog]).
/// * [evdevCodeForUsbHidUsage]: Flutter physical key → evdev code, for
///   recording shortcuts.
library;

export 'src/catalog.dart';
export 'src/generated/evdev_tables.g.dart'
    show generatedForKernelHeaders, generatedForLibevdev;
export 'src/generated/usb_hid_tables.g.dart' show generatedForFlutter;
export 'src/libevdev.dart';
export 'src/libevdev_ffi.dart' show evKey, evRel, keyMax, relMax;
export 'src/usb_hid.dart';
