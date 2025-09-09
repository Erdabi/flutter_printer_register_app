import 'package:esc_pos_utils_plus/esc_pos_utils.dart';
import 'package:intl/intl.dart';

class EscPosHelper {
  Future<List<int>> buildTestTicket() async {
    final profile = await CapabilityProfile.load(); // Standardprofil
    final generator = Generator(PaperSize.mm80, profile);

    final bytes = <int>[];
    bytes.addAll(generator.setGlobalCodeTable('CP1252')); // Umlaute/€-fähig
    bytes.addAll(generator.text(
      'TESTDRUCK',
      styles: const PosStyles(
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
        bold: true,
      ),
    ));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.text(
      'Hello World',
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.text(
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
      styles: const PosStyles(align: PosAlign.center),
    ));
    bytes.addAll(generator.hr());
    bytes.addAll(generator.cut());
    return bytes;
  }

  /// ESC p m t1 t2  -> öffnet Kassenschublade via Drucker (RJ11/RJ12)
  /// m: 0 = Drawer1 (Pin2), 1 = Drawer2 (Pin5)
  /// t1/t2 in 2ms-Schritten (25=50ms, 250=500ms)
  List<int> cashDrawerPulse({int m = 0, int t1 = 0x19, int t2 = 0xFA}) {
    return [0x1B, 0x70, m & 0xFF, t1 & 0xFF, t2 & 0xFF];
  }
}
