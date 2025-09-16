# POS Printer & Cash Drawer Module (Flutter)

This module provides a Flutter integration for **thermal receipt printers** using
**ESC/POS commands** over **Network, USB, or Bluetooth**.  
It also supports sending a pulse to open a **cash drawer**.

---

## 📂 Project Structure

- **main.dart** → App entry point  
- **home_page.dart** → UI for testing printer & cash drawer  
- **config_page.dart** → UI for selecting printer connection  
- **printer_config.dart** → Data model for printer configuration  
- **printer_service.dart** → Handles discovery, connection & data sending  
- **escpos_helper.dart** → Provides ESC/POS commands (print, cut, drawer pulse)  

---

## ⚡ Quick Start

### 1. Import the services

```dart
import 'services/printer_service.dart';
import 'services/escpos_helper.dart';
import 'models/printer_config.dart';
## 2. Create a printer configuration

final cfg = PrinterConfig(
  channel: PrinterChannel.network,
  ip: "192.168.1.100",
  port: 9100,
);
## 3. Print a test ticket

final svc = PrinterService();
final esc = EscPosHelper();

await svc.connect(cfg);
await svc.sendBytes(cfg, await esc.buildTestTicket());
await svc.disconnect(cfg.channel);
## 4. Open the cash drawer

final pulse = EscPosHelper().cashDrawerPulse();
await svc.sendBytes(cfg, pulse);
## Core Functions
## PrinterService (printer_service.dart)
discovery(PrinterChannel ch) → scan for available printers

connect(PrinterConfig cfg) → open a printer connection

disconnect(PrinterChannel ch) → close the connection

sendBytes(PrinterConfig cfg, List<int> bytes) → send ESC/POS commands

## EscPosHelper (escpos_helper.dart)
buildTestTicket() → generate a sample receipt

cashDrawerPulse() → open drawer command

_alignLeft(), _alignCenter() → text alignment helpers

_cut() → cut the paper

## PrinterConfig (printer_config.dart)

enum PrinterChannel { network, bluetooth, usb }

class PrinterConfig {
  PrinterChannel channel;
  String? ip;
  int port;
  String? btName;
  String? btAddress;
  String? usbVendorId;
  String? usbProductId;
}
## UI Pages
HomePage
Shows current printer configuration

Buttons for Print Test and Open Drawer

Navigation to ConfigPage

ConfigPage
Select connection type (Network / Bluetooth / USB)

Enter IP/Port for network printers

Scan for Bluetooth/USB devices

Save & return configuration

## 🔗 Typical Workflow
User opens the app → HomePage

Configures printer via ConfigPage

Presses Print Test → sends ESC/POS test ticket

Presses Open Drawer → sends pulse command

🚀 Reuse in Your Own Code
You can reuse the PrinterService and EscPosHelper in any Flutter app.

Example:


final config = PrinterConfig(channel: PrinterChannel.network, ip: "192.168.0.50", port: 9100);
final printer = PrinterService();
final esc = EscPosHelper();

await printer.connect(config);

// Print order receipt
final orderTicket = await esc.buildTestTicket();
await printer.sendBytes(config, orderTicket);

// Open drawer
await printer.sendBytes(config, esc.cashDrawerPulse());

await printer.disconnect(config.channel);
