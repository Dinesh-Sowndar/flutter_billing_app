import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../domain/repositories/printer_repository.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  final PrinterHelper _printerHelper = PrinterHelper();

  @override
  Future<List<BluetoothInfo>> scanDevices() async {
    if (await _printerHelper.checkPermission()) {
      return await _printerHelper.getBondedDevices();
    }
    throw Exception('Bluetooth permission denied');
  }

  @override
  Future<bool> connect(String macAddress) async {
    return await _printerHelper.connect(macAddress);
  }

  @override
  Future<bool> disconnect() async {
    return await _printerHelper.disconnect();
  }

  @override
  String? getSavedPrinterMac() {
    return HiveDatabase.settingsBox.get('printer_mac');
  }

  @override
  String? getSavedPrinterName() {
    return HiveDatabase.settingsBox.get('printer_name');
  }

  @override
  Future<void> savePrinterData(String mac, String name) async {
    await HiveDatabase.settingsBox.put('printer_mac', mac);
    await HiveDatabase.settingsBox.put('printer_name', name);
  }

  @override
  Future<void> clearPrinterData() async {
    await HiveDatabase.settingsBox.delete('printer_mac');
    await HiveDatabase.settingsBox.delete('printer_name');
  }

  @override
  Future<void> testPrint(String shopName) async {
    await _printerHelper
        .printText("Test Print\n\n$shopName\n\n----------------\n\n");
  }
}
