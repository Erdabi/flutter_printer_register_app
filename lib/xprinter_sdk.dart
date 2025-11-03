import 'package:flutter/services.dart';

class XPrinterSdk {
  static const _ch = MethodChannel('xprinter_sdk');

  static Future<void> init() async => _ch.invokeMethod('init');

  /// Returns a List<String> of USB paths (e.g. /dev/bus/usb/001/002)
  static Future<List<String>> listUsb() async {
    final res = await _ch.invokeMethod('listUsb');
    return (res as List).map((e) => e.toString()).toList();
  }

  /// Connect with optional path. If null, bridge auto-picks first path.
  static Future<bool> connectUsb({String? path}) async {
    return await _ch.invokeMethod('connectUsb', {'path': path});
  }

  static Future<bool> printText(String text) async =>
      await _ch.invokeMethod('printText', {'text': text});

  static Future<void> disconnect() async => _ch.invokeMethod('disconnect');
}
