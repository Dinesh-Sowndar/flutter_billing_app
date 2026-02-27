import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

abstract class PrinterRepository {
  Future<List<BluetoothInfo>> scanDevices();
  Future<bool> connect(String macAddress);
  Future<bool> disconnect();
  String? getSavedPrinterMac();
  String? getSavedPrinterName();
  Future<void> savePrinterData(String mac, String name);
  Future<void> clearPrinterData();
  Future<void> testPrint(String shopName);
}
