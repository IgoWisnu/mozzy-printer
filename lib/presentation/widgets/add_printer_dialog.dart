import 'package:flutter/material.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:provider/provider.dart';
import '../../core/providers/printer_provider.dart';
import '../../data/models/printer_model.dart';

class AddPrinterDialog extends StatefulWidget {
  final PrinterModel? existingPrinter;

  const AddPrinterDialog({super.key, this.existingPrinter});

  @override
  State<AddPrinterDialog> createState() => _AddPrinterDialogState();
}

class _AddPrinterDialogState extends State<AddPrinterDialog> {
  late TextEditingController _nameController;
  String _printArea = 'kitchen';
  PrinterConnectionType _connectionType = PrinterConnectionType.bluetooth;
  Printer? _selectedDevice;
  bool _isEditing = false;

  final List<String> _areas = ['kitchen', 'cashier', 'bar'];

  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingPrinter != null;
    _nameController = TextEditingController(
      text: widget.existingPrinter?.name ?? '',
    );
    if (_isEditing) {
      _printArea = widget.existingPrinter!.printArea;
      _connectionType = widget.existingPrinter!.connectionType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              _isEditing ? 'Edit Printer' : 'Add Printer',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Connection Type Toggle
            Text(
              'Connection Type',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<PrinterConnectionType>(
              segments: const [
                ButtonSegment(
                  value: PrinterConnectionType.bluetooth,
                  label: Text('Bluetooth'),
                  icon: Icon(Icons.bluetooth),
                ),
                ButtonSegment(
                  value: PrinterConnectionType.usb,
                  label: Text('USB'),
                  icon: Icon(Icons.usb),
                ),
              ],
              selected: {_connectionType},
              onSelectionChanged: (val) {
                setState(() {
                  _connectionType = val.first;
                  _selectedDevice = null;
                });
              },
            ),
            const SizedBox(height: 20),

            // Scan for devices
            if (!_isEditing) ...[
              Consumer<PrinterProvider>(
                builder: (_, prov, __) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Devices',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: prov.isScanning
                                ? null
                                : () => prov.startScan(
                                    usb:
                                        _connectionType ==
                                        PrinterConnectionType.usb,
                                  ),
                            icon: prov.isScanning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search, size: 18),
                            label: Text(
                              prov.isScanning ? 'Scanning...' : 'Scan',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (prov.discoveredDevices.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Text(
                                prov.isScanning
                                    ? 'Looking for devices...'
                                    : 'Tap Scan to find devices',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        ...prov.discoveredDevices.map(
                          (device) => ListTile(
                            leading: Radio<Printer>.adaptive(
                              value: device,
                              groupValue: _selectedDevice,
                              onChanged: (val) {
                                setState(() {
                                  _selectedDevice = val;
                                  if (_nameController.text.isEmpty &&
                                      val != null) {
                                    _nameController.text =
                                        val.name ?? 'Unknown';
                                  }
                                });
                              },
                            ),
                            title: Text(device.name ?? 'Unknown'),
                            subtitle: Text(device.address ?? ''),
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onTap: () {
                              setState(() {
                                _selectedDevice = device;
                                if (_nameController.text.isEmpty) {
                                  _nameController.text =
                                      device.name ?? 'Unknown';
                                }
                              });
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Printer Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Printer Name',
                hintText: 'e.g. Kitchen Printer',
                prefixIcon: const Icon(Icons.label),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Print Area Dropdown
            DropdownButtonFormField<String>(
              value: _areas.contains(_printArea) ? _printArea : _areas.first,
              decoration: InputDecoration(
                labelText: 'Print Area',
                prefixIcon: const Icon(Icons.grid_view),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _areas
                  .map(
                    (a) => DropdownMenuItem(
                      value: a,
                      child: Text(a.toUpperCase()),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _printArea = val ?? 'kitchen'),
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _canSave() ? _save : null,
                icon: Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(
                  _isEditing ? 'Save Changes' : 'Add Printer',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  bool _canSave() {
    if (_nameController.text.isEmpty) return false;
    if (!_isEditing && _selectedDevice == null) return false;
    return true;
  }

  Future<void> _save() async {
    final printerProv = context.read<PrinterProvider>();

    if (_isEditing) {
      final updated = widget.existingPrinter!.copyWith(
        name: _nameController.text.trim(),
        printArea: _printArea,
        connectionType: _connectionType,
      );
      await printerProv.updatePrinter(updated);
    } else {
      await printerProv.addPrinter(
        name: _nameController.text.trim(),
        address: _selectedDevice?.address ?? '',
        printArea: _printArea,
        connectionType: _connectionType,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}
