package com.example.flutter_printer_register_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.xprinter.bridge.XPrinterBridge

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    flutterEngine.plugins.add(XPrinterBridge())
  }
}
