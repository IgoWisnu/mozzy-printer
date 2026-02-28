import 'dart:typed_data';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import '../models/print_job_model.dart';

/// Formats a kitchen ticket — items only, large bold text, no pricing.
class KitchenFormatter {
  static Future<Uint8List> format(PrintJobPayload payload) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text(
      '-- KITCHEN --',
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
    bytes += generator.text(
      payload.isDineIn ? 'DINE IN' : 'TAKE AWAY',
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

    // Items — big and bold for kitchen readability
    for (final item in payload.items) {
      final qtyStr = item.quantity % 1 == 0
          ? '${item.quantity.toInt()}'
          : '${item.quantity}';
      bytes += generator.text(
        '${qtyStr}x ${item.name}',
        styles: const PosStyles(
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
        ),
      );
      if (item.note != null && item.note!.isNotEmpty) {
        bytes += generator.text(
          '   >> ${item.note}',
          styles: const PosStyles(bold: true, height: PosTextSize.size1),
        );
      }
    }

    bytes += generator.hr(ch: '=');
    bytes += generator.feed(3);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }
}
