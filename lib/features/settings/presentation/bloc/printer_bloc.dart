import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../domain/repositories/printer_repository.dart';
import 'printer_event.dart';
import 'printer_state.dart';

class PrinterBloc extends Bloc<PrinterEvent, PrinterState> {
  final PrinterRepository repository;

  PrinterBloc({required this.repository}) : super(const PrinterState()) {
    on<InitPrinterEvent>(_onInit);
    on<RefreshPrinterEvent>(_onRefresh);
    on<ScanPrintersEvent>(_onScan);
    on<ConnectPrinterEvent>(_onConnect);
    on<DisconnectPrinterEvent>(_onDisconnect);
    on<TestPrintEvent>(_onTestPrint);
    on<CheckConnectionEvent>(_onCheckConnection);
  }

  /// On init, load saved printer info and verify live BT connection.
  Future<void> _onInit(
      InitPrinterEvent event, Emitter<PrinterState> emit) async {
    final mac = repository.getSavedPrinterMac();
    final name = repository.getSavedPrinterName();

    if (mac == null || mac.isEmpty) {
      // No printer was ever saved
      emit(state.copyWith(
        status: PrinterStatus.disconnected,
        connectedMac: null,
        connectedName: null,
        clearConnectedMac: true,
        clearConnectedName: true,
      ));
      return;
    }

    // We have a saved MAC — check if BT is actually connected right now
    emit(state.copyWith(
      status: PrinterStatus.checking,
      connectedMac: mac,
      connectedName: name,
    ));

    try {
      final btAlive = await PrintBluetoothThermal.connectionStatus;
      if (btAlive) {
        // Sync the singleton helper flag so print methods work
        await PrinterHelper().syncConnectionStatus();
        emit(state.copyWith(
          status: PrinterStatus.connected,
          connectedMac: mac,
          connectedName: name,
        ));
      } else {
        emit(state.copyWith(
          status: PrinterStatus.disconnected,
          connectedMac: mac,
          connectedName: name,
          errorMessage: 'Printer is saved but not connected. Tap refresh to reconnect.',
        ));
      }
    } catch (_) {
      emit(state.copyWith(
        status: PrinterStatus.disconnected,
        connectedMac: mac,
        connectedName: name,
        errorMessage: 'Could not verify printer connection.',
      ));
    }
  }

  /// Check live BT connection status without scanning/reconnecting.
  Future<void> _onCheckConnection(
      CheckConnectionEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.checking, clearError: true));
    try {
      final btAlive = await PrintBluetoothThermal.connectionStatus;
      if (btAlive) {
        emit(state.copyWith(status: PrinterStatus.connected));
      } else {
        emit(state.copyWith(
          status: PrinterStatus.disconnected,
          errorMessage: 'Printer is not reachable. Make sure it is powered on.',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.disconnected,
        errorMessage: 'Connection check failed: $e',
      ));
    }
  }

  Future<void> _onRefresh(
      RefreshPrinterEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.scanning, clearError: true));
    try {
      final devices = await repository.scanDevices();
      if (devices.isEmpty) {
        emit(state.copyWith(
          status: PrinterStatus.scanFailure,
          errorMessage: 'No paired Bluetooth devices found. Pair a printer in Bluetooth settings first.',
          devices: [],
        ));
        return;
      }

      // Try to connect to saved printer first, then iterate all devices
      final savedMac = repository.getSavedPrinterMac();
      bool connected = false;

      if (savedMac != null && savedMac.isNotEmpty) {
        final savedDevice = devices.where((d) => d.macAdress == savedMac);
        if (savedDevice.isNotEmpty) {
          emit(state.copyWith(status: PrinterStatus.connecting));
          final success = await repository.connect(savedMac);
          if (success) {
            await repository.savePrinterData(
                savedMac, savedDevice.first.name);
            emit(state.copyWith(
              status: PrinterStatus.connected,
              connectedMac: savedMac,
              connectedName: savedDevice.first.name,
              devices: devices,
              clearError: true,
            ));
            connected = true;
          }
        }
      }

      if (!connected) {
        // Try all devices
        for (var device in devices) {
          emit(state.copyWith(status: PrinterStatus.connecting));
          final success = await repository.connect(device.macAdress);
          if (success) {
            await repository.savePrinterData(device.macAdress, device.name);
            emit(state.copyWith(
              status: PrinterStatus.connected,
              connectedMac: device.macAdress,
              connectedName: device.name,
              devices: devices,
              clearError: true,
            ));
            connected = true;
            break;
          }
        }
      }

      if (!connected) {
        emit(state.copyWith(
          status: PrinterStatus.connectionFailure,
          errorMessage: 'Found ${devices.length} device(s) but could not connect. Make sure the printer is powered on and nearby.',
          devices: devices,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.scanFailure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onScan(
      ScanPrintersEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.scanning, clearError: true));
    try {
      final devices = await repository.scanDevices();
      emit(state.copyWith(
        status: PrinterStatus.scanSuccess,
        devices: devices,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.scanFailure,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onConnect(
      ConnectPrinterEvent event, Emitter<PrinterState> emit) async {
    emit(state.copyWith(status: PrinterStatus.connecting, clearError: true));
    final success = await repository.connect(event.mac);
    if (success) {
      await repository.savePrinterData(event.mac, event.name);
      emit(state.copyWith(
        status: PrinterStatus.connected,
        connectedMac: event.mac,
        connectedName: event.name,
      ));
    } else {
      emit(state.copyWith(
        status: PrinterStatus.connectionFailure,
        errorMessage: 'Failed to connect to ${event.name}. Ensure the printer is on and in range.',
      ));
    }
  }

  Future<void> _onDisconnect(
      DisconnectPrinterEvent event, Emitter<PrinterState> emit) async {
    await repository.disconnect();
    await repository.clearPrinterData();
    emit(PrinterState(
      status: PrinterStatus.disconnected,
      devices: state.devices,
    ));
  }

  Future<void> _onTestPrint(
      TestPrintEvent event, Emitter<PrinterState> emit) async {
    // Verify connection before attempting test print
    final btAlive = await PrintBluetoothThermal.connectionStatus;
    if (!btAlive) {
      emit(state.copyWith(
        status: PrinterStatus.disconnected,
        errorMessage: 'Printer disconnected. Tap refresh to reconnect before test printing.',
      ));
      return;
    }

    emit(state.copyWith(status: PrinterStatus.testPrinting));
    try {
      await repository.testPrint(event.shopName);
      emit(state.copyWith(status: PrinterStatus.connected));
    } catch (e) {
      emit(state.copyWith(
        status: PrinterStatus.connectionFailure,
        errorMessage: 'Test print failed: $e',
      ));
    }
  }
}
