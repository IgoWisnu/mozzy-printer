import 'dart:typed_data';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import '../models/print_job_model.dart';

/// Formats a kitchen/bar ticket — items with modifiers, no pricing.
class KitchenFormatter {
  static Future<Uint8List> format(PrintJobPayload payload) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header — show the print area name (e.g. KITCHEN, BAR)
    final areaLabel = payload.printArea.isNotEmpty
        ? payload.printArea.toUpperCase()
        : 'KITCHEN';
    bytes += generator.text(
      '-- $areaLabel --',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.hr(ch: '=');

    // Order info
    bytes += generator.text(
      'Order #${payload.orderNumber}',
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    );
    bytes += generator.text(
      'Queue: ${payload.queueNumber}',
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    );

    final dineInLabel = payload.isDineIn
        ? 'DINE IN'
        : (payload.orderType ?? 'TAKE AWAY').toUpperCase();
    bytes += generator.text(
      dineInLabel,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    );

    if (payload.isDineIn && payload.table != null && payload.table != '-') {
      bytes += generator.text(
        'Table: ${payload.table}',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
    }
    if (payload.customerName != null && payload.customerName!.isNotEmpty) {
      bytes += generator.text(
        payload.customerName!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (payload.date != null) {
      bytes += generator.text(
        payload.date!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.hr(ch: '-');

    // Items — same style as receipt (normal size, bold, with modifiers inline)
    for (final item in payload.items) {
      final qtyStr = item.quantity % 1 == 0
          ? '${item.quantity.toInt()}'
          : '${item.quantity}';

      // Item name
      final itemLabel = '${qtyStr}x ${item.name}';

      bytes += generator.text(
        itemLabel,
        styles: const PosStyles(height: PosTextSize.size2),
      );

      if (item.modifiers.isNotEmpty) {
        final modNames = item.modifiers.map((m) => m.name).join(', ');
        bytes += generator.text('  + $modNames');
      }

      // Note
      if (item.note != null && item.note!.isNotEmpty) {
        bytes += generator.text('  ** ${item.note}');
      }
    }

    bytes += generator.hr(ch: '=');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }
}
