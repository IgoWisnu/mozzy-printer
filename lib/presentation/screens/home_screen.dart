import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/printer_provider.dart';
import '../../core/providers/socket_provider.dart';
import '../../data/models/print_job_model.dart';
import '../../data/models/printer_model.dart';
import '../../data/services/socket_service.dart';
import 'printer_management_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mozzy Print Service'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConnectionCard(context),
            const SizedBox(height: 16),
            _buildPrinterStatusSection(context),
            const SizedBox(height: 16),
            _buildRecentJobsSection(context),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<SocketProvider>(
            builder: (_, socket, __) => FloatingActionButton.small(
              heroTag: 'test',
              onPressed:
                  socket.isConnected ||
                      context.read<PrinterProvider>().printers.isNotEmpty
                  ? () => _showTestJobDialog(context)
                  : null,
              tooltip: 'Send Test Job',
              child: const Icon(Icons.bug_report),
            ),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'printers',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const PrinterManagementScreen(),
              ),
            ),
            tooltip: 'Manage Printers',
            child: const Icon(Icons.print),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    return Consumer<SocketProvider>(
      builder: (_, socket, __) {
        final state = socket.connectionState;
        Color statusColor;
        String statusText;
        IconData statusIcon;

        switch (state) {
          case SocketConnectionState.connected:
            statusColor = Colors.green;
            statusText = 'Connected';
            statusIcon = Icons.cloud_done;
            break;
          case SocketConnectionState.connecting:
            statusColor = Colors.orange;
            statusText = 'Connecting...';
            statusIcon = Icons.cloud_upload;
            break;
          case SocketConnectionState.error:
            statusColor = Colors.red;
            statusText = 'Connection Error';
            statusIcon = Icons.cloud_off;
            break;
          case SocketConnectionState.disconnected:
            statusColor = Colors.grey;
            statusText = 'Disconnected';
            statusIcon = Icons.cloud_off;
            break;
        }

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.surface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(statusIcon, color: statusColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Server Connection',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () {
                        if (socket.isConnected) {
                          socket.disconnect();
                        } else {
                          socket.connect();
                        }
                      },
                      child: Text(
                        socket.isConnected ? 'Disconnect' : 'Connect',
                      ),
                    ),
                  ],
                ),
                if (socket.registeredRooms.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: socket.registeredRooms.map((room) {
                      final area = room.split(':').last;
                      return Chip(
                        label: Text(area, style: const TextStyle(fontSize: 12)),
                        avatar: Icon(_getAreaIcon(area), size: 16),
                        visualDensity: VisualDensity.compact,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrinterStatusSection(BuildContext context) {
    return Consumer<PrinterProvider>(
      builder: (_, printerProv, __) {
        final printers = printerProv.printers;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.print, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Printers',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${printers.where((p) => p.isConnected).length}/${printers.length} online',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (printers.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.print_disabled,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No printers configured',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PrinterManagementScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Printer'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...printers.map((printer) => _buildPrinterCard(context, printer)),
          ],
        );
      },
    );
  }

  Widget _buildPrinterCard(BuildContext context, printer) {
    final isOnline = printer.isConnected;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isOnline ? Colors.green : Colors.red.shade400).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            printer.connectionType == PrinterConnectionType.bluetooth
                ? Icons.bluetooth
                : Icons.usb,
            color: isOnline ? Colors.green : Colors.red.shade400,
          ),
        ),
        title: Text(
          printer.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(printer.printArea.toUpperCase()),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isOnline ? Colors.green : Colors.red.shade400).withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.red.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isOnline ? Colors.green : Colors.red.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentJobsSection(BuildContext context) {
    return Consumer<SocketProvider>(
      builder: (_, socket, __) {
        final jobs = socket.recentJobs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Recent Jobs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${jobs.length} jobs',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (jobs.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 48,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No print jobs yet',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              ...jobs.take(10).map((job) => _buildJobTile(context, job)),
          ],
        );
      },
    );
  }

  Widget _buildJobTile(BuildContext context, PrintJobModel job) {
    Color statusColor;
    IconData statusIcon;
    switch (job.status) {
      case PrintJobStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case PrintJobStatus.printing:
        statusColor = Colors.blue;
        statusIcon = Icons.print;
        break;
      case PrintJobStatus.success:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case PrintJobStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        dense: true,
        leading: Icon(statusIcon, color: statusColor, size: 20),
        title: Text(
          'Order #${job.payload.orderNumber} — ${job.printArea}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          job.errorMessage ??
              job.status.toString().split('.').last.toUpperCase(),
          style: TextStyle(fontSize: 12, color: statusColor),
        ),
        trailing: Text(
          '${job.receivedAt.hour.toString().padLeft(2, '0')}:${job.receivedAt.minute.toString().padLeft(2, '0')}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  void _showTestJobDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Test Print Job'),
        content: const Text('Select the print area to test:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SocketProvider>().sendTestJob('kitchen');
            },
            child: const Text('🍳 Kitchen'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SocketProvider>().sendTestJob('cashier');
            },
            child: const Text('🧾 Cashier'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  IconData _getAreaIcon(String area) {
    switch (area.toLowerCase()) {
      case 'kitchen':
        return Icons.restaurant;
      case 'cashier':
        return Icons.point_of_sale;
      case 'bar':
        return Icons.local_bar;
      default:
        return Icons.print;
    }
  }
}
