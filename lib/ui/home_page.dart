import 'package:flutter/material.dart';
import '../models/printer_config.dart';
import '../services/escpos_helper.dart';
import '../services/printer_service.dart';
import 'config_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _esc = EscPosHelper();
  final _svc = PrinterService();

  PrinterConfig _cfg = PrinterConfig(channel: PrinterChannel.network, ip: '192.168.1.50', port: 9100);
  bool _busy = false;
  String _status = 'Bereit';

  Future<void> _guarded(Future<void> Function() run) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _svc.connect(_cfg);
      await run();
      setState(() => _status = 'OK');
    } catch (e) {
      setState(() => _status = 'Fehler: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    } finally {
      try { await _svc.disconnect(_cfg.channel); } catch (_) {}
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _printTest() async {
    final bytes = await _esc.buildTestTicket();
    await _svc.sendBytes(_cfg, bytes);
  }

  Future<void> _openDrawer() async {
    final pulse = _esc.cashDrawerPulse(m: 0, t1: 0x19, t2: 0xFA);
    await _svc.sendBytes(_cfg, pulse);
  }

  Future<void> _openConfig() async {
    final updated = await Navigator.push<PrinterConfig>(
      context,
      MaterialPageRoute(builder: (_) => ConfigPage(initial: _cfg)),
    );
    if (updated != null) setState(() => _cfg = updated);
  }

  @override
  Widget build(BuildContext context) {
    final btnStyle = ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48));
    return Scaffold(
      appBar: AppBar(title: const Text('Thermodrucker & Kassenschublade')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Verbindung'),
              subtitle: Text(
                switch (_cfg.channel) {
                  PrinterChannel.network => 'Netzwerk: ${_cfg.ip}:${_cfg.port}',
                  PrinterChannel.bluetooth => 'Bluetooth: ${_cfg.btName ?? ''} (${_cfg.btAddress ?? ''})',
                  PrinterChannel.usb => 'USB: VID=${_cfg.usbVendorId?.toRadixString(16)}, PID=${_cfg.usbProductId?.toRadixString(16)}',
                },
              ),
              trailing: IconButton(icon: const Icon(Icons.settings), onPressed: _busy ? null : _openConfig),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: btnStyle,
              onPressed: _busy ? null : () => _guarded(_printTest),
              icon: const Icon(Icons.print),
              label: const Text('Testdruck'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              style: btnStyle,
              onPressed: _busy ? null : () => _guarded(_openDrawer),
              icon: const Icon(Icons.lock_open),
              label: const Text('Kassenschublade öffnen'),
            ),
            const Spacer(),
            Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                Expanded(child: Text(_status)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
