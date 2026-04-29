import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../data/models/print_job_model.dart';
import '../../data/models/printer_model.dart';
import '../../data/services/socket_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/thermal_printer_service.dart';
import '../../data/formatters/kitchen_formatter.dart';
import '../../data/formatters/receipt_formatter.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  // If the service is already running (e.g. from a previous app session),
  // don't reconfigure — just reuse the existing instance.
  final isRunning = await service.isRunning();
  if (isRunning) {
    debugPrint('🔄 Background service already running, skipping configure');
    return;
  }

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'mozzy_print_service_channel',
    'Mozzy Print Service',
    description: 'Keeps the Socket.IO print service running in the background',
    importance: Importance.low,
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
      foregroundServiceTypes: [
        AndroidForegroundType.dataSync,
        AndroidForegroundType.connectedDevice,
      ],
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

  // CRITICAL: Set as foreground service IMMEDIATELY — before any async work.
  // Android 12+ requires startForeground() within ~5 seconds.
  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Show initial notification right away
  if (service is AndroidServiceInstance) {
    flutterLocalNotificationsPlugin.show(
      id: 888,
      title: 'Mozzy Print Service',
      body: 'Starting...',
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

  // Now safe to do async initialization
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

  // --- Local printer list (kept in sync via 'update-printers' events) ---
  List<PrinterModel> localPrinters = storageService.printers;
  debugPrint('📋 Loaded ${localPrinters.length} printers from storage');

  // --- Printing Logic ---
  Future<void> processJobData(
    Map<String, dynamic> data, {
    bool isTestJob = false,
  }) async {
    try {
      final job = PrintJobModel.fromSocketData(data);

      final mappedPrinters = localPrinters
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
          // Generate ESC/POS bytes
          final area = job.printArea.toLowerCase();
          final isCashier = area == 'cashier' || area == 'kasir';
          final bytes = isCashier
              ? await ReceiptFormatter.format(job.payload)
              : await KitchenFormatter.format(job.payload);

          if (pm.connectionType.toString().split('.').last == 'lan') {
            try {
              final socket = await Socket.connect(pm.address, 9100, timeout: const Duration(seconds: 5));
              socket.add(bytes);
              await socket.flush();
              await socket.close();
              successCount++;
              debugPrint('✅ Printed to LAN printer ${pm.name} (${pm.address})');
            } catch (e) {
              debugPrint('❌ Print error to LAN printer ${pm.name}: $e');
            }
            continue;
          }

          Printer device;
          bool needsFreshConnection = false;

          if (connectedDevices.containsKey(pm.address)) {
            device = connectedDevices[pm.address]!;
            debugPrint('♻️ Reusing existing connection to ${pm.name}');
          } else {
            needsFreshConnection = true;
            device = Printer(
              address: pm.address,
              name: pm.name,
              connectionType:
                  pm.connectionType.toString().split('.').last == 'bluetooth'
                  ? ConnectionType.BLE
                  : ConnectionType.USB,
            );
          }

          if (needsFreshConnection) {
            final isConnected = await thermalPrinterService.connectToPrinter(
              device,
            );
            if (!isConnected) {
              debugPrint('❌ Could not connect to ${pm.name} (${pm.address})');
              continue;
            }
            connectedDevices[pm.address] = device;
          }

          // Print the bytes
          final printed = await thermalPrinterService.printBytes(device, bytes);
          if (printed) {
            successCount++;
          } else {
            // Print failed — clear cache and try reconnecting once
            debugPrint(
              '⚠️ Print failed for ${pm.name}, retrying with fresh connection...',
            );
            connectedDevices.remove(pm.address);
            final retryDevice = Printer(
              address: pm.address,
              name: pm.name,
              connectionType:
                  pm.connectionType.toString().split('.').last == 'bluetooth'
                  ? ConnectionType.BLE
                  : ConnectionType.USB,
            );
            final reconnected = await thermalPrinterService.connectToPrinter(
              retryDevice,
            );
            if (reconnected) {
              connectedDevices[pm.address] = retryDevice;
              final retryPrinted = await thermalPrinterService.printBytes(
                retryDevice,
                bytes,
              );
              if (retryPrinted) successCount++;
            } else {
              debugPrint('❌ Retry failed for ${pm.name} (${pm.address})');
            }
          }
        } catch (e) {
          debugPrint('❌ Print error to ${pm.name}: $e');
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
    debugPrint('⚙️ update-settings received');
    socketService.disconnect();

    // Read settings directly from the event data (not SharedPreferences)
    // This avoids cross-isolate SharedPreferences cache issues
    String newUrl = '';
    String newKey = '';
    List<String> newAreas = [];

    if (event != null) {
      newUrl = event['serverUrl'] as String? ?? '';
      newKey = event['apiKey'] as String? ?? '';
      final rawAreas = event['printAreas'];
      if (rawAreas is List) {
        newAreas = rawAreas.cast<String>();
      }
    }

    // Fallback to StorageService if event data is empty
    // (e.g. when PrinterProvider triggers update-settings without data)
    if (newUrl.isEmpty || newKey.isEmpty) {
      try {
        await storageService.init();
        newUrl = storageService.serverUrl;
        newKey = storageService.apiKey;
        newAreas = storageService.printAreas;
      } catch (e) {
        debugPrint('⚠️ Failed to read from SharedPreferences: $e');
      }
    }

    debugPrint(
      '⚙️ Server URL: "$newUrl", API Key: "${newKey.isNotEmpty ? "***set***" : "empty"}"',
    );

    if (newUrl.isNotEmpty && newKey.isNotEmpty) {
      debugPrint('🔄 Background service reconnecting to: $newUrl');
      socketService.connect(serverUrl: newUrl, apiKey: newKey);
      // Print areas will be registered automatically by the connection state listener
      // but we also store them for the auto-register callback
      if (newAreas.isNotEmpty) {
        // Update local reference so the connection listener can use them
        storageService.setServerUrl(newUrl);
        storageService.setApiKey(newKey);
        storageService.setPrintAreas(newAreas);
      }
    } else {
      debugPrint('⚠️ Cannot connect: URL or Key is empty');
    }
  });

  service.on('disconnect').listen((event) {
    socketService.disconnect();
  });

  // Allow the UI to request current connection state
  service.on('request-state').listen((_) {
    final stateStr = socketService.currentState.toString().split('.').last;
    service.invoke('socket-state', {'state': stateStr});
  });

  service.on('update-printers').listen((event) {
    if (event == null) return;
    final printersJsonStr = event['printers'] as String?;
    if (printersJsonStr != null) {
      try {
        final list = jsonDecode(printersJsonStr) as List<dynamic>;
        localPrinters = list
            .map((e) => PrinterModel.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint(
          '📋 Updated local printers: ${localPrinters.length} printers',
        );
        for (final p in localPrinters) {
          debugPrint('   - ${p.name} → ${p.printArea} (${p.address})');
        }
      } catch (e) {
        debugPrint('⚠️ Error parsing printers: $e');
      }
    }
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
