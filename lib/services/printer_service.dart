import 'dart:async';
import 'package:thermal_printer/thermal_printer.dart';
import '../models/printer_config.dart';

/// PrinterService that matches the slimmer thermal_printer API in your build.
/// - USB VID/PID are **Strings**.
/// - If VID/PID are missing, auto-scan and use the first attached device (or the one
///   whose toString() contains an XPrinter pattern).
/// - Bluetooth requires MAC address (btAddress).
class PrinterService {
  final PrinterManager _pm = PrinterManager.instance;

  // Local connection flags (plugin has no isConnected()).
  final Map<PrinterType, bool> _connected = {
    PrinterType.network: false,
    PrinterType.bluetooth: false,
    PrinterType.usb: false,
  };

  // -------------------- Discovery --------------------

  Stream<PrinterDevice> discovery(PrinterChannel ch, {bool isBle = false}) {
    return _pm.discovery(type: _mapType(ch), isBle: isBle);
  }

  Future<List<PrinterDevice>> _scanOnce(PrinterType type, {Duration timeout = const Duration(seconds: 2)}) async {
    final out = <PrinterDevice>[];
    final sub = _pm.discovery(type: type).listen(out.add, onError: (_) {});
    await Future.delayed(timeout);
    await sub.cancel();
    return out;
  }

  Future<List<PrinterDevice>> listUsbOnce({Duration timeout = const Duration(seconds: 2)}) {
    return _scanOnce(PrinterType.usb, timeout: timeout);
  }

  // -------------------- Connect/Disconnect --------------------

  Future<void> connect(PrinterConfig cfg) async {
    switch (cfg.channel) {
      case PrinterChannel.network:
        final ip = (cfg.ip ?? '').trim();
        if (ip.isEmpty) {
          throw StateError('IP address is required for network printers.');
        }
        final port = cfg.port == 0 ? 9100 : cfg.port;
        await _pm.connect(
          type: PrinterType.network,
          model: TcpPrinterInput(ipAddress: ip, port: port, timeout: const Duration(seconds: 5)),
        );
        _connected[PrinterType.network] = true;
        return;

      case PrinterChannel.bluetooth:
        final mac = (cfg.btAddress ?? '').trim();
        if (mac.isEmpty) {
          throw StateError('Bluetooth requires btAddress (MAC).');
        }
        await _pm.connect(
          type: PrinterType.bluetooth,
          model: BluetoothPrinterInput(address: mac),
        );
        _connected[PrinterType.bluetooth] = true;
        return;

      case PrinterChannel.usb:
        await _connectUsb(cfg);
        return;
    }
  }

  Future<void> disconnect(PrinterChannel ch) async {
    final t = _mapType(ch);
    await _pm.disconnect(type: t);
    _connected[t] = false;
  }

  bool isConnected(PrinterChannel ch) => _connected[_mapType(ch)] ?? false;

  // -------------------- Send helpers --------------------

  Future<void> sendBytes(PrinterConfig cfg, List<int> bytes) async {
    await _pm.send(type: _mapType(cfg.channel), bytes: bytes);
  }

  Future<void> testPrint(PrinterConfig cfg, List<int> data) async {
    if (!isConnected(cfg.channel)) {
      await connect(cfg);
    }
    await sendBytes(cfg, data);
  }

  Future<void> openCashDrawer(PrinterConfig cfg, List<int> pulseBytes) async {
    if (!isConnected(cfg.channel)) {
      await connect(cfg);
    }
    await sendBytes(cfg, pulseBytes);
  }

  // -------------------- USB internals --------------------

  Future<void> _connectUsb(PrinterConfig cfg) async {
    // normalize any messy values coming from UI
    String? vid = _normalizeUsbId(cfg.usbVendorId);
    String? pid = _normalizeUsbId(cfg.usbProductId);

    final devices = await listUsbOnce(timeout: const Duration(seconds: 2));
    if (devices.isEmpty) {
      throw StateError('No USB devices found. Ensure OTG/USB Host is active and permission granted.');
    }

    // If not provided, pick an XPrinter-looking device first; else first in list.
    PrinterDevice? chosen;
    if (vid != null && pid != null) {
      chosen = _findByVidPid(devices, vid, pid);
    }
    chosen ??= _findByString(devices, patterns: const ['xprinter', 'xp-', 'xp58', 'xp-80']);
    chosen ??= devices.first;

    // If still missing, derive VID/PID from the chosen device.
    vid ??= _normalizeUsbId(_safeString(chosen.vendorId));
    pid ??= _normalizeUsbId(_safeString(chosen.productId));

    if (vid == null || pid == null) {
      throw StateError(
        'Found a USB device but could not determine VID/PID (vendorId=${chosen.vendorId}, productId=${chosen.productId}).',
      );
    }

    // Connect with simple model (no unsupported params).
    await _pm.connect(
      type: PrinterType.usb,
      model: UsbPrinterInput(
        vendorId: vid,
        productId: pid,
      ),
    );
    _connected[PrinterType.usb] = true;
  }

  // -------------------- Helpers --------------------

  PrinterType _mapType(PrinterChannel ch) {
    switch (ch) {
      case PrinterChannel.network:
        return PrinterType.network;
      case PrinterChannel.bluetooth:
        return PrinterType.bluetooth;
      case PrinterChannel.usb:
        return PrinterType.usb;
    }
  }

  /// Accepts: "0x0416", " 0416 ", "1046", "VID: 0x0416", etc. -> returns clean String.
  String? _normalizeUsbId(String? raw) {
    if (raw == null) return null;
    final v = raw.trim();
    if (v.isEmpty) return null;

    final m0x = RegExp(r'0[xX]([0-9A-Fa-f]+)').firstMatch(v);
    if (m0x != null) return m0x.group(1)!; // hex without 0x

    final hex = RegExp(r'\b([0-9A-Fa-f]{3,8})\b').firstMatch(v);
    if (hex != null) return hex.group(1)!;

    final dec = RegExp(r'\b(\d{3,8})\b').firstMatch(v);
    if (dec != null) return dec.group(1)!;

    return null;
  }

  PrinterDevice? _findByVidPid(List<PrinterDevice> list, String vid, String pid) {
    bool match(dynamic v, String needle) {
      final s = _safeString(v);
      if (s == null) return false;
      final norm = _normalizeUsbId(s);
      return norm != null && norm.toLowerCase() == needle.toLowerCase();
    }

    for (final d in list) {
      if (match(d.vendorId, vid) && match(d.productId, pid)) return d;
    }
    return null;
  }

  /// Some plugin builds don’t expose name fields. Use device.toString() as a fallback.
  PrinterDevice? _findByString(List<PrinterDevice> list, {required List<String> patterns}) {
    for (final d in list) {
      final s = d.toString().toLowerCase();
      for (final p in patterns) {
        if (s.contains(p)) return d;
      }
    }
    return null;
  }

  String? _safeString(dynamic v) {
    if (v == null) return null;
    return v.toString();
  }
}