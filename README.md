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
