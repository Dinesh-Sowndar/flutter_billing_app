import 'package:equatable/equatable.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

enum PrinterStatus {
  initial,
  checking,
  scanning,
  scanSuccess,
  scanFailure,
  connecting,
  connected,
  connectionFailure,
  disconnected,
  testPrinting,
}

class PrinterState extends Equatable {
  final PrinterStatus status;
  final String? connectedMac;
  final String? connectedName;
  final List<BluetoothInfo> devices;
  final String? errorMessage;

  const PrinterState({
    this.status = PrinterStatus.initial,
    this.connectedMac,
    this.connectedName,
    this.devices = const [],
    this.errorMessage,
  });

  /// Whether the printer is currently live-connected.
  bool get isLiveConnected => status == PrinterStatus.connected;

  /// Whether a saved printer exists (even if not currently connected).
  bool get hasSavedPrinter =>
      connectedMac != null && connectedMac!.isNotEmpty;

  /// Whether the bloc is currently performing an async operation.
  bool get isBusy =>
      status == PrinterStatus.scanning ||
      status == PrinterStatus.connecting ||
      status == PrinterStatus.checking ||
      status == PrinterStatus.testPrinting;

  PrinterState copyWith({
    PrinterStatus? status,
    String? connectedMac,
    String? connectedName,
    List<BluetoothInfo>? devices,
    String? errorMessage,
    bool clearError = false,
    bool clearConnectedMac = false,
    bool clearConnectedName = false,
  }) {
    return PrinterState(
      status: status ?? this.status,
      connectedMac:
          clearConnectedMac ? null : (connectedMac ?? this.connectedMac),
      connectedName:
          clearConnectedName ? null : (connectedName ?? this.connectedName),
      devices: devices ?? this.devices,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props =>
      [status, connectedMac, connectedName, devices, errorMessage];
}
