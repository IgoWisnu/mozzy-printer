import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../data/models/printer_model.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/thermal_printer_service.dart';

class PrinterProvider extends ChangeNotifier {
  final StorageService _storage;
  final ThermalPrinterService _thermalService;

  List<PrinterModel> _printers = [];
  List<Printer> _discoveredDevices = [];
  bool _isScanning = false;
  StreamSubscription? _scanSub;

  PrinterProvider({
    required StorageService storage,
    required ThermalPrinterService thermalService,
  }) : _storage = storage,
       _thermalService = thermalService {
    _printers = _storage.printers;
  }

  // ─── Getters ────────────────────────────────────────────
  List<PrinterModel> get printers => List.unmodifiable(_printers);
  List<Printer> get discoveredDevices => _discoveredDevices;
  bool get isScanning => _isScanning;

  PrinterModel? getPrinterForArea(String printArea) {
    try {
      return _printers.firstWhere((p) => p.printArea == printArea);
    } catch (_) {
      return null;
    }
  }

  // ─── CRUD ───────────────────────────────────────────────
  Future<void> addPrinter({
    required String name,
    required String address,
    required String printArea,
    required PrinterConnectionType connectionType,
  }) async {
    final printer = PrinterModel(
      id: const Uuid().v4(),
      name: name,
      address: address,
      printArea: printArea,
      connectionType: connectionType,
    );
    _printers.add(printer);
    await _storage.savePrinters(_printers);
    FlutterBackgroundService().invoke('update-settings');
    notifyListeners();
  }

  Future<void> updatePrinter(PrinterModel updated) async {
    final idx = _printers.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      _printers[idx] = updated;
      await _storage.savePrinters(_printers);
      FlutterBackgroundService().invoke('update-settings');
      notifyListeners();
    }
  }

  Future<void> deletePrinter(String id) async {
    _printers.removeWhere((p) => p.id == id);
    await _storage.savePrinters(_printers);
    FlutterBackgroundService().invoke('update-settings');
    notifyListeners();
  }

  // ─── Scanning ───────────────────────────────────────────
  Future<void> startScan({bool usb = false}) async {
    _isScanning = true;
    _discoveredDevices = [];
    notifyListeners();

    _scanSub?.cancel();
    _scanSub = _thermalService.devicesStream.listen((devices) {
      _discoveredDevices = devices;
      notifyListeners();
    });

    if (usb) {
      await _thermalService.startUsbScan();
    } else {
      await _thermalService.startBluetoothScan();
    }

    // Auto-stop after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (_isScanning) {
        _isScanning = false;
        _thermalService.stopScan();
        notifyListeners();
      }
    });
  }

  void stopScan() {
    _scanSub?.cancel();
    _thermalService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  // ─── Connection Management ──────────────────────────────
  // Note: Actual BLE connections are managed by the background service.
  // The foreground only marks the printer as "ready" in UI and saves config.
  // The background service will connect on-demand when a print job arrives.
  Future<bool> connectPrinter(PrinterModel printerModel) async {
    final idx = _printers.indexWhere((p) => p.id == printerModel.id);
    if (idx != -1) {
      _printers[idx] = _printers[idx].copyWith(isConnected: true);
      await _storage.savePrinters(_printers);
      FlutterBackgroundService().invoke('update-settings');
      notifyListeners();
    }
    return true;
  }

  Future<void> disconnectPrinter(String printerId) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx != -1) {
      _printers[idx] = _printers[idx].copyWith(isConnected: false);
      await _storage.savePrinters(_printers);
      FlutterBackgroundService().invoke('update-settings');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    super.dispose();
  }
}
