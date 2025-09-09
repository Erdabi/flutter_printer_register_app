import 'package:flutter/material.dart';
import '../models/printer_config.dart';
import '../services/printer_service.dart';
import 'dart:async';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key, required this.initial});
  final PrinterConfig initial;

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late PrinterConfig cfg;
  final _svc = PrinterService();
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '9100');

  StreamSubscription? _scanSub;
  final List<Map<String, dynamic>> _found = [];

  @override
  void initState() {
    super.initState();
    cfg = PrinterConfig(
      channel: widget.initial.channel,
      ip: widget.initial.ip,
      port: widget.initial.port,
      btName: widget.initial.btName,
      btAddress: widget.initial.btAddress,
      usbVendorId: widget.initial.usbVendorId,
      usbProductId: widget.initial.usbProductId,
    );
    _ip.text = cfg.ip ?? '';
    _port.text = cfg.port.toString();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  void _startScan() {
    _found.clear();
    _scanSub?.cancel();
    final isBle = false; // bei Bedarf BLE aktivieren
    _scanSub = _svc.discovery(cfg.channel, isBle: isBle).listen((d) {
      setState(() {
        _found.add({
          'name': d.name,
          'address': d.address,
          'vendorId': d.vendorId,
          'productId': d.productId,
        });
      });
    });
  }

  Widget _networkFields() => Column(
    children: [
      TextField(controller: _ip, decoration: const InputDecoration(labelText: 'IP-Adresse')),
      TextField(controller: _port, decoration: const InputDecoration(labelText: 'Port (Standard 9100)'), keyboardType: TextInputType.number),
    ],
  );

  Widget _scanList() => Column(
    children: [
      Row(
        children: [
          ElevatedButton.icon(onPressed: _startScan, icon: const Icon(Icons.search), label: const Text('Suchen')),
          const SizedBox(width: 12),
          Text('Gefunden: ${_found.length}'),
        ],
      ),
      const SizedBox(height: 8),
      ..._found.map((e) => ListTile(
        title: Text(e['name']?.toString() ?? 'Unbekannt'),
        subtitle: Text([
          if (e['address'] != null) 'Addr: ${e['address']}',
          if (e['vendorId'] != null) 'VID: ${e['vendorId']}',
          if (e['productId'] != null) 'PID: ${e['productId']}',
        ].join('  |  ')),
        onTap: () {
          setState(() {
            if (cfg.channel == PrinterChannel.bluetooth) {
              cfg.btName = e['name']?.toString();
              cfg.btAddress = e['address']?.toString();
            } else if (cfg.channel == PrinterChannel.usb) {
              cfg.usbVendorId = e['vendorId'] as int?;
              cfg.usbProductId = e['productId'] as int?;
            }
          });
        },
      )),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drucker konfigurieren')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<PrinterChannel>(
              segments: const [
                ButtonSegment(value: PrinterChannel.network, label: Text('Netzwerk')),
                ButtonSegment(value: PrinterChannel.bluetooth, label: Text('Bluetooth')),
                ButtonSegment(value: PrinterChannel.usb, label: Text('USB')),
              ],
              selected: {cfg.channel},
              onSelectionChanged: (s) => setState(() => cfg.channel = s.first),
            ),
            const SizedBox(height: 16),
            if (cfg.channel == PrinterChannel.network) _networkFields(),
            if (cfg.channel == PrinterChannel.bluetooth || cfg.channel == PrinterChannel.usb) _scanList(),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                if (cfg.channel == PrinterChannel.network) {
                  cfg.ip = _ip.text.trim();
                  cfg.port = int.tryParse(_port.text.trim()) ?? 9100;
                }
                Navigator.pop(context, cfg);
              },
              icon: const Icon(Icons.save),
              label: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
