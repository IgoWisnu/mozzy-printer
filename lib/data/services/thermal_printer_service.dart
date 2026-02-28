import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:permission_handler/permission_handler.dart';

class ThermalPrinterService {
  final FlutterThermalPrinter _plugin = FlutterThermalPrinter.instance;

  /// Stream of available devices — directly from flutter_thermal_printer
  Stream<List<Printer>> get devicesStream => _plugin.devicesStream;

  /// Request BLE & Location permissions (required on Android 12+)
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final allGranted = statuses.values.every((s) => s.isGranted || s.isLimited);

    if (!allGranted) {
      debugPrint('❌ BLE permissions not granted: $statuses');
    } else {
      debugPrint('✅ BLE permissions granted');
    }

    return allGranted;
  }

  /// Check and turn on Bluetooth if needed
  Future<bool> ensureBluetoothOn() async {
    try {
      final isOn = await _plugin.isBleTurnedOn();
      if (!isOn) {
        debugPrint('📱 Bluetooth is OFF, requesting to turn on...');
        await _plugin.turnOnBluetooth();
        // Wait a moment for BT to initialize
        await Future.delayed(const Duration(seconds: 1));
        return await _plugin.isBleTurnedOn();
      }
      return true;
    } catch (e) {
      debugPrint('❌ Bluetooth check error: $e');
      return false;
    }
  }

  /// Start scanning for Bluetooth devices (with permission check)
  Future<void> startBluetoothScan() async {
    // 1. Request permissions
    final hasPermissions = await requestPermissions();
    if (!hasPermissions) {
      debugPrint('❌ Cannot scan: permissions not granted');
      return;
    }

    // 2. Ensure Bluetooth is on
    final btOn = await ensureBluetoothOn();
    if (!btOn) {
      debugPrint('❌ Cannot scan: Bluetooth is off');
      return;
    }

    // 3. Start scan
    try {
      await _plugin.getPrinters(connectionTypes: [ConnectionType.BLE]);
      debugPrint('📱 Started BLE scan');
    } catch (e) {
      debugPrint('❌ Bluetooth scan error: $e');
    }
  }

  /// Start scanning for USB devices
  Future<void> startUsbScan() async {
    try {
      await _plugin.getPrinters(connectionTypes: [ConnectionType.USB]);
      debugPrint('🔌 Started USB scan');
    } catch (e) {
      debugPrint('❌ USB scan error: $e');
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await _plugin.stopScan();
    } catch (e) {
      debugPrint('❌ Stop scan error: $e');
    }
  }

  /// Connect to a specific printer
  Future<bool> connectToPrinter(Printer printer) async {
    try {
      final result = await _plugin.connect(printer);
      debugPrint('✅ Connected to ${printer.name}: $result');
      return result;
    } catch (e) {
      debugPrint('❌ Connect error: $e');
      return false;
    }
  }

  /// Disconnect from a printer
  Future<void> disconnectPrinter(Printer printer) async {
    try {
      await _plugin.disconnect(printer);
      debugPrint('🔌 Disconnected from ${printer.name}');
    } catch (e) {
      debugPrint('❌ Disconnect error: $e');
    }
  }

  /// Print raw ESC/POS bytes
  Future<bool> printBytes(Printer printer, Uint8List data) async {
    try {
      await _plugin.printData(printer, data.toList());
      debugPrint('✅ Printed to ${printer.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Print error: $e');
      return false;
    }
  }
}
