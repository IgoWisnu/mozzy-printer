import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../data/models/print_job_model.dart';
import '../../data/services/socket_service.dart' show SocketConnectionState;

class SocketProvider extends ChangeNotifier {
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  final List<String> _registeredRooms = [];
  final List<PrintJobModel> _recentJobs = [];
  StreamSubscription? _connectionSub;
  StreamSubscription? _printJobSub;
  StreamSubscription? _statusUpdatedSub;
  StreamSubscription? _statusErrorSub;

  static const int _maxRecentJobs = 50;

  SocketProvider() {
    _setupListeners();
  }

  // ─── Getters ────────────────────────────────────────────
  SocketConnectionState get connectionState => _connectionState;
  List<String> get registeredRooms => List.unmodifiable(_registeredRooms);
  List<PrintJobModel> get recentJobs => List.unmodifiable(_recentJobs);

  bool get isConnected => _connectionState == SocketConnectionState.connected;
  bool get isConnecting => _connectionState == SocketConnectionState.connecting;

  // ─── Connection ─────────────────────────────────────────
  void connect() {
    FlutterBackgroundService().invoke('update-settings');
  }

  void disconnect() {
    FlutterBackgroundService().invoke('disconnect');
  }

  // ─── Listeners ──────────────────────────────────────────
  void _setupListeners() {
    final service = FlutterBackgroundService();

    _connectionSub = service.on('socket-state').listen((event) {
      if (event == null) return;
      final stateStr = event['state'] as String;
      _connectionState = SocketConnectionState.values.firstWhere(
        (e) => e.toString().split('.').last == stateStr,
        orElse: () => SocketConnectionState.disconnected,
      );
      notifyListeners();
    });

    _printJobSub = service.on('print-job').listen((event) {
      if (event == null) return;
      final data = Map<String, dynamic>.from(event);
      final job = PrintJobModel.fromSocketData(data);
      job.status = PrintJobStatus.printing;
      _addJob(job);
    });

    _statusUpdatedSub = service.on('job-status-update').listen((event) {
      if (event == null) return;
      final jobId = event['id'] as int;
      final status = event['status'] as String;
      _updateJobStatus(jobId, status);
    });

    _statusErrorSub = service.on('job-status-error').listen((event) {
      if (event == null) return;
      debugPrint('Job status error from background: ${event['error']}');
      // Update UI if needed
    });
  }

  void _addJob(PrintJobModel job) {
    _recentJobs.insert(0, job);
    if (_recentJobs.length > _maxRecentJobs) {
      _recentJobs.removeLast();
    }
    notifyListeners();
  }

  void _updateJobStatus(int jobId, String status) {
    final idx = _recentJobs.indexWhere((j) => j.id == jobId);
    if (idx != -1) {
      _recentJobs[idx].status = PrintJobStatus.values.firstWhere(
        (e) => e.toString().split('.').last == status,
        orElse: () => PrintJobStatus.failed,
      );
      notifyListeners();
    }
  }

  // ─── Test / Mock Job ────────────────────────────────────
  Future<void> sendTestJob(String printArea) async {
    FlutterBackgroundService().invoke('test-print', {'area': printArea});
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _printJobSub?.cancel();
    _statusUpdatedSub?.cancel();
    _statusErrorSub?.cancel();
    super.dispose();
  }
}
