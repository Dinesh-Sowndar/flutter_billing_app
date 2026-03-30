import 'package:intl/intl.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';

class EscPos {
  static const List<int> init = [0x1B, 0x40];
  static const List<int> alignCenter = [0x1B, 0x61, 0x01];
  static const List<int> alignLeft = [0x1B, 0x61, 0x00];
  static const List<int> alignRight = [0x1B, 0x61, 0x02];
  static const List<int> boldOn = [0x1B, 0x45, 0x01];
  static const List<int> boldOff = [0x1B, 0x45, 0x00];
  static const List<int> textNormal = [0x1D, 0x21, 0x00];
  static const List<int> textLarge = [0x1D, 0x21, 0x11];
  static const List<int> lineFeed = [0x0A];

  /// Generate ESC/POS bytes for a QR code using native GS ( k commands.
  /// Works on most 58mm / 80mm thermal printers.
  static List<int> qrCode(String data,
      {int moduleSize = 6, int errorCorrection = 49}) {
    final List<int> bytes = [];
    final dataBytes = data.codeUnits;
    final store = dataBytes.length + 3; // pL pH includes cn + fn + data

    // 1. Set QR model to Model 2
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // 2. Set module size (dot size of each QR module)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize]);

    // 3. Set error correction level (48=L, 49=M, 50=Q, 51=H)
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, errorCorrection]);

    // 4. Store QR data  GS ( k pL pH cn fn data
    bytes.addAll([
      0x1D, 0x28, 0x6B,
      store & 0xFF, (store >> 8) & 0xFF, // pL, pH
      0x31, 0x50, 0x30, // cn=49, fn=80, m=48
    ]);
    bytes.addAll(dataBytes);

    // 5. Print the stored QR code
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    return bytes;
  }
}

class PrinterHelper {
  // Singleton
  static final PrinterHelper _instance = PrinterHelper._internal();
  factory PrinterHelper() => _instance;
  PrinterHelper._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  /// Sync the internal flag with the actual BT connection status.
  /// Call this after verifying connection externally (e.g. in bloc init).
  Future<void> syncConnectionStatus() async {
    _isConnected = await PrintBluetoothThermal.connectionStatus;
  }

  Future<bool> checkPermission() async {
    // Request Bluetooth and Location permissions
    // Android 12+ needs BLUETOOTH_SCAN, BLUETOOTH_CONNECT
    // Older Android needs BLUETOOTH, BLUETOOTH_ADMIN, ACCESS_FINE_LOCATION

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<List<BluetoothInfo>> getBondedDevices() async {
    try {
      final List<BluetoothInfo> list =
          await PrintBluetoothThermal.pairedBluetooths;
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> connect(String macAddress) async {
    try {
      final bool result =
          await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
      _isConnected = result;
      return result;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected =
          !result; // If disconnected successfully, isConnected is false
      return result;
    } catch (e) {
      return false;
    }
  }

  Future<void> printText(String text) async {
    final bool alive = await PrintBluetoothThermal.connectionStatus;
    if (!alive) return;
    _isConnected = true;

    // Simple text printing
    // We can use bytes for advanced formatting
    // But plugin supports basic text or bytes

    // Checking battery or connection status
    final bool connectionStatus = await PrintBluetoothThermal.connectionStatus;
    if (connectionStatus) {
      // Plugin allows sending bytes. We need ESC/POS commands for text.
      // However, the plugin might have helper.
      // Looking at doc, `writeBytes` or `writeString`?
      // The plugin `print_bluetooth_thermal` mainly exposes `writeBytes`.
      // We need a generator. `esc_pos_utils` is common but not requested.
      // But wait, `print_bluetooth_thermal` example often uses `capability_profile` and `generator`.
      // I don't have `esc_pos_utils` or similar in my pubspec.
      // The user requested `print_bluetooth_thermal`.
      // Let's assume we can send raw string bytes or use a simple helper.
      // Actually without `esc_pos_utils`, formatting is hard.
      // I will try to use `esc_pos_utils_plus` or similar if I can add it, but user gave specific packages.
      // Wait, user allowed "use required plugins".
      // "suggest barcode scanner ... and use required plugins".
      // So I can add `esc_pos_utils_plus`.

      // For now, I'll assume simple text printing by converting string to bytes.
      // ASCII bytes.
      List<int> bytes = text.codeUnits;
      await PrintBluetoothThermal.writeBytes(bytes);
    }
  }

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items, // Name, Qty, Price, Total
    required double total, // subtotal (cart items only)
    required double prevDue, // previous outstanding balance
    required double amountPaid, // amount the customer paid now
    required String footer,
    String customerName = '',
    String partyLabel = 'Customer',
    String paymentMethod = 'cash',
    String upiId = '',
    double gstRate = 0.0,
    double cgstAmount = 0.0,
    double sgstAmount = 0.0,
    String gstNumber = '',
  }) async {
    final bool alive = await PrintBluetoothThermal.connectionStatus;
    if (!alive) return;
    _isConnected = true;

    // Construct ESC/POS bytes manually or using helper
    List<int> bytes = [];

    // Init
    bytes += EscPos.init;

    // Shop Name (Center, Bold, Large)
    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += _textToBytes(shopName);
    bytes += EscPos.lineFeed;

    // Address & Phone (Normal, Center)
    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;
    if (address1.isNotEmpty) {
      bytes += _textToBytes(address1);
      bytes += EscPos.lineFeed;
    }
    if (address2.isNotEmpty) {
      bytes += _textToBytes(address2);
      bytes += EscPos.lineFeed;
    }
    bytes += _textToBytes(phone);
    bytes += EscPos.lineFeed;

    // GSTIN (if available)
    if (gstNumber.isNotEmpty) {
      bytes += EscPos.boldOn;
      bytes += _textToBytes('GSTIN: $gstNumber');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
    }

    // Date and Time
    String formattedDate =
        DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now());
    bytes += _textToBytes(formattedDate);
    bytes += EscPos.lineFeed;

    // Invoice type label when GST is enabled
    if (gstRate > 0) {
      bytes += EscPos.boldOn;
      bytes += _textToBytes('TAX INVOICE');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Header (Align Left)
    bytes += EscPos.alignLeft;
    bytes += _textToBytes('Item            Price   Total');
    bytes += EscPos.lineFeed;
    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // Items
    for (var item in items) {
      String name = item['name'].toString();
      String qty = item['qty'].toString();
      String price = item['price'].toString();
      String totalItem = item['total'].toString();

      String prefix = '${qty}x $name';
      if (prefix.length > 16) prefix = prefix.substring(0, 16);

      String line = prefix.padRight(16) + price.padRight(8) + totalItem;
      bytes += _textToBytes(line);
      bytes += EscPos.lineFeed;
    }

    bytes += _textToBytes('--------------------------------');
    bytes += EscPos.lineFeed;

    // ── GST Breakdown (if enabled) ────────────────────────────────────
    if (gstRate > 0) {
      final taxableAmount = total / (1 + gstRate / 100);
      final halfRate = gstRate / 2;

      bytes += EscPos.alignLeft;
      String taxableLine = 'Taxable Amt:'.padRight(20) +
          'Rs ${taxableAmount.toStringAsFixed(2)}'.padLeft(12);
      bytes += _textToBytes(taxableLine);
      bytes += EscPos.lineFeed;

      String cgstLine = 'CGST @ ${halfRate.toStringAsFixed(1)}%:'.padRight(20) +
          'Rs ${cgstAmount.toStringAsFixed(2)}'.padLeft(12);
      bytes += _textToBytes(cgstLine);
      bytes += EscPos.lineFeed;

      String sgstLine = 'SGST @ ${halfRate.toStringAsFixed(1)}%:'.padRight(20) +
          'Rs ${sgstAmount.toStringAsFixed(2)}'.padLeft(12);
      bytes += _textToBytes(sgstLine);
      bytes += EscPos.lineFeed;

      bytes += _textToBytes('--------------------------------');
      bytes += EscPos.lineFeed;
    }
    // ─────────────────────────────────────────────────────────────────

    // Show full breakdown only when there is prev due OR remaining balance.
    // If customer paid in full with no prev due, just print "TOTAL" (cleaner receipt).
    final _balance =
        ((total + prevDue) - amountPaid).clamp(0.0, total + prevDue);
    final bool isCustomerBill = prevDue > 0 || _balance > 0;

    // Print party name on every bill (customer/supplier) when provided.
    if (customerName.isNotEmpty) {
      bytes += EscPos.alignLeft;
      bytes += EscPos.boldOn;
      bytes += _textToBytes('$partyLabel: $customerName');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
    }

    if (isCustomerBill) {
      // ── Full breakdown for customer bills ────────────────────────────
      final grandTotal = total + prevDue;
      final balance = (grandTotal - amountPaid).clamp(0.0, grandTotal);
      final hasPrevDue = prevDue > 0;

      bytes += EscPos.alignLeft;

      // Sub Total
      String subTotalLine = 'Sub Total:'.padRight(20) +
          'Rs ${total.toStringAsFixed(2)}'.padLeft(12);
      bytes += _textToBytes(subTotalLine);
      bytes += EscPos.lineFeed;

      // Previous Due (only if > 0)
      if (hasPrevDue) {
        String prevDueLine = 'Prev. Due:'.padRight(20) +
            'Rs ${prevDue.toStringAsFixed(2)}'.padLeft(12);
        bytes += _textToBytes(prevDueLine);
        bytes += EscPos.lineFeed;
        bytes += _textToBytes('--------------------------------');
        bytes += EscPos.lineFeed;
      }

      // Grand Total (bold, right-aligned)
      bytes += EscPos.alignRight;
      bytes += EscPos.boldOn;
      String grandTotalLabel = hasPrevDue ? 'GRAND TOTAL:' : 'TOTAL:';
      bytes +=
          _textToBytes('$grandTotalLabel Rs ${grandTotal.toStringAsFixed(2)}');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;

      // Amount Paid
      bytes += EscPos.alignLeft;
      bytes += EscPos.textNormal;
      String receivedLine = 'Amount Paid:'.padRight(20) +
          'Rs ${amountPaid.toStringAsFixed(2)}'.padLeft(12);
      bytes += _textToBytes(receivedLine);
      bytes += EscPos.lineFeed;

      // Balance Due
      if (balance > 0) {
        bytes += EscPos.boldOn;
        String balanceLine = 'Balance Due:'.padRight(20) +
            'Rs ${balance.toStringAsFixed(2)}'.padLeft(12);
        bytes += _textToBytes(balanceLine);
        bytes += EscPos.boldOff;
        bytes += EscPos.lineFeed;
      } else {
        bytes +=
            _textToBytes('Balance Due:'.padRight(20) + 'Rs 0.00'.padLeft(12));
        bytes += EscPos.lineFeed;
      }

      bytes += EscPos.lineFeed;
      // ─────────────────────────────────────────────────────────────────
    } else {
      // ── Simple total for walk-in / guest bills ───────────────────────
      bytes += EscPos.alignRight;
      bytes += EscPos.boldOn;
      bytes += _textToBytes('TOTAL: Rs ${total.toStringAsFixed(2)}');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
      // ─────────────────────────────────────────────────────────────────
    }

    // ── UPI QR Code (only when payment method is UPI and upiId exists) ──
    if (paymentMethod.toLowerCase() == 'upi' && upiId.isNotEmpty) {
      final amountToPay = isCustomerBill
          ? (total + prevDue).toStringAsFixed(2)
          : total.toStringAsFixed(2);
      final upiUri =
          'upi://pay?pa=$upiId&pn=${Uri.encodeComponent(shopName)}&am=$amountToPay&cu=INR';

      bytes += EscPos.alignCenter;
      bytes += _textToBytes('--------------------------------');
      bytes += EscPos.lineFeed;
      bytes += EscPos.boldOn;
      bytes += _textToBytes('Scan to Pay via UPI');
      bytes += EscPos.boldOff;
      bytes += EscPos.lineFeed;
      bytes += EscPos.lineFeed;
      bytes += EscPos.qrCode(upiUri);
      bytes += EscPos.lineFeed;
      bytes += _textToBytes(upiId);
      bytes += EscPos.lineFeed;
    }

    // Footer (Center)
    bytes += EscPos.alignCenter;
    bytes += _textToBytes(footer);
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed; // One line space after footer
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed; // Additional Feed

    await PrintBluetoothThermal.writeBytes(bytes);
  }

  List<int> _textToBytes(String text) {
    // Should verify encoding, but Latin-1 usually works for basic printers
    return List.from(text.codeUnits);
  }
}
