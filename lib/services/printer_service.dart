import 'dart:async';
import 'dart:io';
import 'package:thermal_printer/thermal_printer.dart';
import '../models/printer_config.dart';

class PrinterService {
  final _pm = PrinterManager.instance;

  Future<void> ensurePermissions() async {
    // Das Plugin selbst handhabt vieles – hier optional via permission_handler nachhelfen,
    // insbesondere für Android 12+ Bluetooth.
    // (Wenn Ihr Projekt bereits ein globales Permission-Handling hat, dort einhängen.)
  }

  Stream<PrinterDevice> discovery(PrinterChannel ch, {bool isBle = false}) {
    final type = _mapType(ch);
    return _pm.discovery(type: type, isBle: isBle);
  }

  Future<void> connect(PrinterConfig cfg, {bool reconnect = false, bool isBle = false}) async {
    switch (cfg.channel) {
      case PrinterChannel.usb:
        if (cfg.usbVendorId == null || cfg.usbProductId == null) {
          throw Exception('USB VendorId/ProductId fehlen.');
        }
        await _pm.connect(
          type: PrinterType.usb,
          model: UsbPrinterInput(
            name: 'USB',
            productId: cfg.usbProductId, // String
    vendorId: cfg.usbVendorId,
          ),
        );
        break;

      case PrinterChannel.bluetooth:
        if (cfg.btAddress == null || cfg.btName == null) {
          throw Exception('Bluetooth Name/Adresse fehlen.');
        }
        await _pm.connect(
          type: PrinterType.bluetooth,
          model: BluetoothPrinterInput(
            name: cfg.btName!,
            address: cfg.btAddress!,
            isBle: isBle,
            autoConnect: reconnect,
          ),
        );
        break;

      case PrinterChannel.network:
        if (cfg.ip == null) throw Exception('IP-Adresse fehlt.');
        await _pm.connect(
          type: PrinterType.network,
          model: TcpPrinterInput(ipAddress: cfg.ip!, port: cfg.port),
        );
        break;
    }
  }

  Future<void> disconnect(PrinterChannel ch) => _pm.disconnect(type: _mapType(ch));  // ✅


  Future<void> sendBytes(PrinterConfig cfg, List<int> bytes) async {
    await _pm.send(type: _mapType(cfg.channel), bytes: bytes);
  }

  PrinterType _mapType(PrinterChannel ch) {
    switch (ch) {
      case PrinterChannel.network: return PrinterType.network;
      case PrinterChannel.bluetooth: return PrinterType.bluetooth;
      case PrinterChannel.usb: return PrinterType.usb;
    }
  }
}
