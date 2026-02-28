import 'dart:typed_data';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import '../models/print_job_model.dart';

/// Formats a cashier receipt — full order details with pricing and payment.
class ReceiptFormatter {
  static Future<Uint8List> format(PrintJobPayload payload) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // Store / Business Header
    if (payload.storeName != null && payload.storeName!.isNotEmpty) {
      bytes += generator.text(
        payload.storeName!,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }
    if (payload.storeAddress != null && payload.storeAddress!.isNotEmpty) {
      bytes += generator.text(
        payload.storeAddress!,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (payload.storePhone != null && payload.storePhone!.isNotEmpty) {
      bytes += generator.text(
        'Tel: ${payload.storePhone}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.hr(ch: '=');

    // Order details
    bytes += generator.text(
      'Order #${payload.orderNumber}',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.text(
      'Queue: ${payload.queueNumber}',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      payload.isDineIn ? 'DINE IN' : 'TAKE AWAY',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    if (payload.isDineIn && payload.table != null && payload.table != '-') {
      bytes += generator.text(
        'Table: ${payload.table}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (payload.customerName != null && payload.customerName!.isNotEmpty) {
      bytes += generator.text(
        'Customer: ${payload.customerName}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (payload.cashierName != null && payload.cashierName!.isNotEmpty) {
      bytes += generator.text(
        'Cashier: ${payload.cashierName}',
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

    // Items
    for (final item in payload.items) {
      final qtyStr = item.quantity % 1 == 0
          ? '${item.quantity.toInt()}'
          : '${item.quantity}';
      bytes += generator.row([
        PosColumn(
          text: '${qtyStr}x',
          width: 2,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(text: item.name, width: 7),
        PosColumn(
          text: _formatCurrency(item.totalPrice),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      if (item.note != null && item.note!.isNotEmpty) {
        bytes += generator.text(
          '   Note: ${item.note}',
          styles: const PosStyles(fontType: PosFontType.fontB),
        );
      }
    }

    bytes += generator.hr(ch: '-');

    // Totals
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 7),
      PosColumn(
        text: _formatCurrency(payload.subtotal),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (payload.taxAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Tax', width: 7),
        PosColumn(
          text: _formatCurrency(payload.taxAmount),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (payload.feesAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Fees', width: 7),
        PosColumn(
          text: _formatCurrency(payload.feesAmount),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr(ch: '-');
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 7,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: _formatCurrency(payload.grandTotal),
        width: 5,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
        ),
      ),
    ]);

    // Payment
    bytes += generator.hr(ch: '-');
    if (payload.paymentMethod != null) {
      bytes += generator.row([
        PosColumn(text: 'Payment', width: 7),
        PosColumn(
          text: payload.paymentMethod!,
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.row([
      PosColumn(text: 'Paid', width: 7),
      PosColumn(
        text: _formatCurrency(payload.payAmount),
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (payload.changeAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Change', width: 7),
        PosColumn(
          text: _formatCurrency(payload.changeAmount),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (payload.paymentStatus != null) {
      bytes += generator.text(
        payload.paymentStatus!,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
    }

    bytes += generator.hr(ch: '=');
    bytes += generator.text(
      'Thank you!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  static String _formatCurrency(num amount) {
    final formatted = amount.toStringAsFixed(0);
    // Add thousand separators
    final result = StringBuffer();
    int count = 0;
    for (int i = formatted.length - 1; i >= 0; i--) {
      result.write(formatted[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        result.write('.');
      }
    }
    return result.toString().split('').reversed.join('');
  }
}
