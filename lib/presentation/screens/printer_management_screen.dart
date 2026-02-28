import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/printer_provider.dart';
import '../../core/providers/socket_provider.dart';
import '../../data/models/printer_model.dart';
import '../widgets/add_printer_dialog.dart';

class PrinterManagementScreen extends StatelessWidget {
  const PrinterManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Management'),
        centerTitle: true,
      ),
      body: Consumer<PrinterProvider>(
        builder: (_, printerProv, __) {
          final printers = printerProv.printers;

          if (printers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.print_disabled,
                    size: 80,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No printers configured',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a printer to start receiving print jobs',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showAddPrinterDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Printer'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: printers.length,
            itemBuilder: (_, i) => _buildPrinterTile(context, printers[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddPrinterDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Printer'),
      ),
    );
  }

  Widget _buildPrinterTile(BuildContext context, PrinterModel printer) {
    final isOnline = printer.isConnected;
    final printerProv = context.read<PrinterProvider>();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    printer.connectionType == PrinterConnectionType.bluetooth
                        ? Icons.bluetooth
                        : Icons.usb,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        printer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        printer.address,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isOnline ? Colors.green : Colors.red.shade400)
                        .withValues(alpha: 0.12),
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
              ],
            ),
            const SizedBox(height: 12),
            // Print area chip
            Row(
              children: [
                Chip(
                  label: Text(
                    printer.printArea.toUpperCase(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  avatar: Icon(_getAreaIcon(printer.printArea), size: 16),
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                // Connection type label
                Text(
                  printer.connectionType == PrinterConnectionType.bluetooth
                      ? 'Bluetooth'
                      : 'USB',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (isOnline) {
                        await printerProv.disconnectPrinter(printer.id);
                      } else {
                        // Scan first if needed
                        if (printerProv.discoveredDevices.isEmpty) {
                          await printerProv.startScan(
                            usb:
                                printer.connectionType ==
                                PrinterConnectionType.usb,
                          );
                          // Wait a bit for scanning
                          await Future.delayed(const Duration(seconds: 3));
                        }
                        await printerProv.connectPrinter(printer);
                      }
                    },
                    icon: Icon(
                      isOnline ? Icons.link_off : Icons.link,
                      size: 18,
                    ),
                    label: Text(isOnline ? 'Disconnect' : 'Connect'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showTestPrint(context, printer),
                  icon: const Icon(Icons.receipt, size: 18),
                  label: const Text('Test'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _showEditDialog(context, printer),
                  icon: const Icon(Icons.edit, size: 20),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: () => _confirmDelete(context, printer),
                  icon: Icon(
                    Icons.delete,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPrinterDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const AddPrinterDialog(),
    );
  }

  void _showEditDialog(BuildContext context, PrinterModel printer) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => AddPrinterDialog(existingPrinter: printer),
    );
  }

  void _confirmDelete(BuildContext context, PrinterModel printer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Printer'),
        content: Text('Are you sure you want to delete "${printer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              context.read<PrinterProvider>().deletePrinter(printer.id);
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showTestPrint(BuildContext context, PrinterModel printer) {
    context.read<SocketProvider>().sendTestJob(printer.printArea);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Test print job sent to ${printer.name} (${printer.printArea})',
        ),
        behavior: SnackBarBehavior.floating,
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
