import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/models/print_job_model.dart';
import '../../data/services/socket_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/thermal_printer_service.dart';
import '../../data/formatters/kitchen_formatter.dart';
import '../../data/formatters/receipt_formatter.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mozzy_print_service_channel', // id
    'Mozzy Print Service', // name
    description: 'Keeps the Socket.IO print service running in the background',
    importance: Importance.low, // importance must be at low or higher level
  );

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'mozzy_print_service_channel',
      initialNotificationTitle: 'Mozzy Print Service',
      initialNotificationContent: 'Initializing...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final storageService = StorageService();
  await storageService.init();

  final socketService = SocketService();
  final thermalPrinterService = ThermalPrinterService();

  // Function to update the persistent notification
  void updateNotification(String content) {
    if (service is AndroidServiceInstance) {
      flutterLocalNotificationsPlugin.show(
        id: 888,
        title: 'Mozzy Print Service (Background)',
        body: content,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'mozzy_print_service_channel',
            'Mozzy Print Service',
            icon: 'ic_bg_service_small',
            ongoing: true,
          ),
        ),
      );
    }
  }

  // --- Keep a map of connected devices so we don't reconnect each time ---
  final Map<String, Printer> connectedDevices = {};

  // --- Printing Logic ---
  Future<void> processJobData(
    Map<String, dynamic> data, {
    bool isTestJob = false,
  }) async {
    try {
      final job = PrintJobModel.fromSocketData(data);

      // Reload printers from storage to get latest config
      await storageService.init();
      final mappedPrinters = storageService.printers
          .where(
            (p) => p.printArea.toLowerCase() == job.printArea.toLowerCase(),
          )
          .toList();

      if (mappedPrinters.isEmpty) {
        if (!isTestJob) {
          socketService.reportJobStatus(
            jobId: job.id,
            status: 'failed',
            errorMessage: 'No mapped printers for area: ${job.printArea}',
          );
        }
        service.invoke('job-status-error', {
          'error': 'No mapped printers for area: ${job.printArea}',
        });
        return;
      }

      if (!isTestJob) {
        socketService.reportJobStatus(jobId: job.id, status: 'printing');
      }

      int successCount = 0;
      for (final pm in mappedPrinters) {
        try {
          // Reuse existing connection or create a new one
          Printer device;
          if (connectedDevices.containsKey(pm.address)) {
            device = connectedDevices[pm.address]!;
            debugPrint('♻️ Reusing existing connection to ${pm.name}');
          } else {
            device = Printer(
              address: pm.address,
              name: pm.name,
              connectionType:
                  pm.connectionType.toString().split('.').last == 'bluetooth'
                  ? ConnectionType.BLE
                  : ConnectionType.USB,
            );

            final isConnected = await thermalPrinterService.connectToPrinter(
              device,
            );
            if (!isConnected) {
              debugPrint('❌ Could not connect to ${pm.name}');
              continue;
            }
            connectedDevices[pm.address] = device;
          }

          // Generate ESC/POS bytes
          final bytes = job.printArea.toLowerCase() == 'kitchen'
              ? await KitchenFormatter.format(job.payload)
              : await ReceiptFormatter.format(job.payload);

          // Print the bytes (keep the connection alive for future jobs)
          final printed = await thermalPrinterService.printBytes(device, bytes);
          if (printed) successCount++;
        } catch (e) {
          debugPrint('Print error to ${pm.name}: $e');
          // Remove from cache if the connection died
          connectedDevices.remove(pm.address);
        }
      }

      if (successCount > 0) {
        if (!isTestJob) {
          socketService.reportJobStatus(jobId: job.id, status: 'success');
        }
        service.invoke('job-status-update', {
          'id': job.id,
          'status': 'success',
        });
      } else {
        if (!isTestJob) {
          socketService.reportJobStatus(
            jobId: job.id,
            status: 'failed',
            errorMessage: 'All printers failed',
          );
        }
        service.invoke('job-status-error', {
          'error': 'All mapped printers failed to print',
        });
      }
    } catch (e) {
      debugPrint('Error processing job background: $e');
    }
  }

  // Socket setup — auto-register print areas when connected
  socketService.connectionState.listen((state) {
    service.invoke('socket-state', {'state': state.name});
    updateNotification('Socket: ${state.name}');

    // Auto-register print areas once connected
    if (state == SocketConnectionState.connected) {
      final currentAreas = storageService.printAreas;
      if (currentAreas.isNotEmpty) {
        debugPrint('📡 Auto-registering print areas: $currentAreas');
        socketService.registerPrintAreas(currentAreas);
      }
    }
  });

  socketService.printJobs.listen((data) {
    debugPrint('🖨️ Background received print job');
    service.invoke('print-job', data);
    processJobData(data, isTestJob: false);
  });

  socketService.jobStatusUpdated.listen((data) {
    service.invoke('job-status-updated', data);
  });

  socketService.jobStatusError.listen((err) {
    service.invoke('job-status-error', {'error': err});
  });

  // Try connecting initially
  final url = storageService.serverUrl;
  final key = storageService.apiKey;

  if (url.isNotEmpty && key.isNotEmpty) {
    debugPrint('🔌 Background service connecting to: $url');
    socketService.connect(serverUrl: url, apiKey: key);
    // Print areas will be registered automatically by the listener above
  }

  // Listen for commands from the UI
  service.on('update-settings').listen((event) async {
    await storageService.init(); // Refresh settings from SharedPreferences
    socketService.disconnect();

    final newUrl = storageService.serverUrl;
    final newKey = storageService.apiKey;

    if (newUrl.isNotEmpty && newKey.isNotEmpty) {
      debugPrint('🔄 Background service reconnecting to: $newUrl');
      socketService.connect(serverUrl: newUrl, apiKey: newKey);
      // Print areas will be registered automatically by the listener above
    }
  });

  service.on('disconnect').listen((event) {
    socketService.disconnect();
  });

  service.on('test-print').listen((event) async {
    if (event == null) return;
    final area = event['area'] as String? ?? 'cashier';
    // Create mock job data
    final mockData = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'orderId': 9999,
      'orderNumber': 'TEST-123',
      'printArea': area,
      'status': 'pending',
      'receivedAt': DateTime.now().toIso8601String(),
      'payload': {
        'print_area': area,
        'orderNumber': 'TEST-123',
        'customerName': 'Test Name',
        'orderType': 'Dine In',
        'queueNumber': 99,
        'items': [
          {
            'itemId': 1,
            'itemName': 'Test Item 1',
            'quantity': 1,
            'price': 15000,
          },
          {
            'itemId': 2,
            'itemName': 'Test Item 2',
            'quantity': 2,
            'price': 10000,
          },
        ],
        'subtotal': 35000,
        'tax': 3500,
        'total': 38500,
        'timestamp': DateTime.now().toIso8601String(),
      },
    };
    // isTestJob = true → don't report to backend
    processJobData(mockData, isTestJob: true);
  });
}
