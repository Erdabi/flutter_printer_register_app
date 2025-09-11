import 'dart:convert';
import 'package:intl/intl.dart';

/// Basit ESC/POS yardımcıları (harici paket kullanmadan)
class EscPosHelper {
  // Reset
  List<int> _init() => [0x1B, 0x40]; // ESC @
  // Justification
  List<int> _alignCenter() => [0x1B, 0x61, 0x01]; // ESC a 1
  List<int> _alignLeft() => [0x1B, 0x61, 0x00];   // ESC a 0
  // Double font on/off
  List<int> _doubleOn() => [0x1D, 0x21, 0x11];    // GS ! 17 (HxW=2x)
  List<int> _doubleOff() => [0x1D, 0x21, 0x00];   // GS ! 0
  // Western Europe codepage (CP1252 çoğu yazıcıda 16)
  List<int> _cp1252() => [0x1B, 0x74, 16];        // ESC t 16
  // Cut
  List<int> _cut() => [0x1D, 0x56, 0x00];         // GS V 0 (full cut)
  // Yazı yardımcıları
  List<int> _ln(String s) => [...utf8.encode(s), 0x0A];
  List<int> _feed(int n) => List<int>.filled(n, 0x0A);

  Future<List<int>> buildTestTicket() async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final bytes = <int>[];

    bytes.addAll(_init());
    bytes.addAll(_cp1252());
    bytes.addAll(_alignCenter());
    bytes.addAll(_doubleOn());
    bytes.addAll(_ln('TESTDRUCK'));
    bytes.addAll(_doubleOff());
    bytes.addAll(_ln('------------------------------'));
    bytes.addAll(_ln('Hello World'));
    bytes.addAll(_ln(now));
    bytes.addAll(_ln('------------------------------'));
    bytes.addAll(_feed(3));
    bytes.addAll(_cut());

    return bytes;
  }

  /// ESC p m t1 t2 -> Kassenschublade (Drawer) pulse
  List<int> cashDrawerPulse({int m = 0, int t1 = 0x19, int t2 = 0xFA}) =>
      [0x1B, 0x70, m & 0xFF, t1 & 0xFF, t2 & 0xFF];
}
