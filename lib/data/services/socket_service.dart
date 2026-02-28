import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

enum SocketConnectionState { disconnected, connecting, connected, error }

class SocketService {
  sio.Socket? _socket;
  final _connectionStateController =
      StreamController<SocketConnectionState>.broadcast();
  final _printJobController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _registerSuccessController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _jobStatusUpdatedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _jobStatusErrorController = StreamController<String>.broadcast();

  SocketConnectionState _state = SocketConnectionState.disconnected;

  Stream<SocketConnectionState> get connectionState =>
      _connectionStateController.stream;
  Stream<Map<String, dynamic>> get printJobs => _printJobController.stream;
  Stream<Map<String, dynamic>> get registerSuccess =>
      _registerSuccessController.stream;
  Stream<Map<String, dynamic>> get jobStatusUpdated =>
      _jobStatusUpdatedController.stream;
  Stream<String> get jobStatusError => _jobStatusErrorController.stream;

  SocketConnectionState get currentState => _state;

  void connect({required String serverUrl, required String apiKey}) {
    disconnect();

    _updateState(SocketConnectionState.connecting);

    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .setQuery({'apiKey': apiKey})
          .enableReconnection()
          .setReconnectionDelay(3000)
          .setReconnectionAttempts(double.maxFinite.toInt())
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('✅ Connected to POS server');
      _updateState(SocketConnectionState.connected);
    });

    _socket!.onConnectError((err) {
      debugPrint('❌ Connection error: $err');
      _updateState(SocketConnectionState.error);
    });

    _socket!.onDisconnect((reason) {
      debugPrint('⚠️ Disconnected: $reason');
      _updateState(SocketConnectionState.disconnected);
    });

    _socket!.onReconnect((_) {
      debugPrint('✅ Reconnected');
      _updateState(SocketConnectionState.connected);
    });

    _socket!.onReconnectAttempt((_) {
      debugPrint('🔄 Reconnecting...');
      _updateState(SocketConnectionState.connecting);
    });

    // Listen for print jobs
    _socket!.on('print-job', (data) {
      debugPrint('🖨️ Received print job: ${data['id']}');
      _printJobController.add(Map<String, dynamic>.from(data as Map));
    });

    // Listen for register success
    _socket!.on('register-success', (data) {
      debugPrint('📡 Register success: $data');
      _registerSuccessController.add(Map<String, dynamic>.from(data as Map));
    });

    // Listen for job status updates
    _socket!.on('job-status-updated', (data) {
      debugPrint('📋 Job status updated: $data');
      _jobStatusUpdatedController.add(Map<String, dynamic>.from(data as Map));
    });

    // Listen for job status errors
    _socket!.on('job-status-error', (data) {
      debugPrint('⚠️ Job status error: $data');
      _jobStatusErrorController.add(
        data is Map ? data['message'] as String : data.toString(),
      );
    });

    _socket!.connect();
  }

  void registerPrintAreas(List<String> printAreas) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Cannot register: not connected');
      return;
    }
    _socket!.emit('register-printer', {'printAreas': printAreas});
  }

  void reportJobStatus({
    required int jobId,
    required String status,
    String? errorMessage,
  }) {
    if (_socket == null || !_socket!.connected) {
      debugPrint('Cannot report status: not connected');
      return;
    }
    final payload = <String, dynamic>{'id': jobId, 'status': status};
    if (errorMessage != null) {
      payload['errorMessage'] = errorMessage;
    }
    _socket!.emit('job-status-update', payload);
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _updateState(SocketConnectionState.disconnected);
  }

  void _updateState(SocketConnectionState state) {
    _state = state;
    _connectionStateController.add(state);
  }

  void dispose() {
    disconnect();
    _connectionStateController.close();
    _printJobController.close();
    _registerSuccessController.close();
    _jobStatusUpdatedController.close();
    _jobStatusErrorController.close();
  }
}
