enum PrinterChannel { network, bluetooth, usb }

class PrinterConfig {
  PrinterChannel channel;
  String? ip;      // network
  int port;
  String? btName;  // bluetooth classic/ble
  String? btAddress;
  int? usbVendorId; // usb
  int? usbProductId;

  PrinterConfig({
    required this.channel,
    this.ip,
    this.port = 9100,
    this.btName,
    this.btAddress,
    this.usbVendorId,
    this.usbProductId,
  });
}
