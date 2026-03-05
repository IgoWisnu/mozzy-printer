import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../../data/services/storage_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _serverUrlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _customAreaController;
  bool _obscureApiKey = true;
  List<String> _selectedAreas = [];
  final List<String> _availableAreas = ['kitchen', 'cashier', 'bar'];

  @override
  void initState() {
    super.initState();
    final storage = context.read<StorageService>();
    _serverUrlController = TextEditingController(text: storage.serverUrl);
    _apiKeyController = TextEditingController(text: storage.apiKey);
    _customAreaController = TextEditingController();
    _selectedAreas = List.from(storage.printAreas);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    _customAreaController.dispose();
    super.dispose();
  }

  void _addCustomArea() {
    final val = _customAreaController.text.trim().toLowerCase();
    if (val.isNotEmpty && !_selectedAreas.contains(val)) {
      setState(() {
        if (!_availableAreas.contains(val)) {
          _availableAreas.add(val);
        }
        _selectedAreas.add(val);
      });
      _customAreaController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server Connection Section
            _buildSectionHeader(context, 'Server Connection', Icons.dns),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _serverUrlController,
                      decoration: InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'http://192.168.1.100:3001',
                        prefixIcon: const Icon(Icons.link),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscureApiKey = !_obscureApiKey),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Print Areas Section
            _buildSectionHeader(context, 'Print Areas', Icons.grid_view),
            const SizedBox(height: 8),
            Text(
              'Select the print areas this device will handle',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableAreas.map((area) {
                        final selected = _selectedAreas.contains(area);
                        return FilterChip(
                          label: Text(area.toUpperCase()),
                          selected: selected,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedAreas.add(area);
                              } else {
                                _selectedAreas.remove(area);
                              }
                            });
                          },
                          avatar: Icon(_getAreaIcon(area), size: 18),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    // Custom area input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _customAreaController,
                            decoration: InputDecoration(
                              labelText: 'Custom Area',
                              hintText: 'e.g. bar, patio',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              isDense: true,
                            ),
                            onSubmitted: (_) => _addCustomArea(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(
                          onPressed: _addCustomArea,
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Save & Reconnect',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _saveSettings() async {
    final storage = context.read<StorageService>();

    final url = _serverUrlController.text.trim();
    final key = _apiKeyController.text.trim();

    await storage.setServerUrl(url);
    await storage.setApiKey(key);
    await storage.setPrintAreas(_selectedAreas);

    // Pass settings directly to the background service via event data
    // (avoids SharedPreferences cache issues in the background isolate)
    FlutterBackgroundService().invoke('update-settings', {
      'serverUrl': url,
      'apiKey': key,
      'printAreas': _selectedAreas,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved! Reconnecting...'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
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
