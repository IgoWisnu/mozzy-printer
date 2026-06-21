import 'dart:typed_data';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import '../models/print_job_model.dart';

/// Formats a full receipt for cashier/kasir printers.
class ReceiptFormatter {
  static Future<Uint8List> format(PrintJobPayload payload) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // ─── Store Header ───
    if (payload.storeName != null && payload.storeName!.isNotEmpty) {
      bytes += generator.text(
        payload.storeName!,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size1,
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

    // ─── Order Info ───
    bytes += generator.text(
      'Order #${payload.orderNumber}',
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
      ),
    );
    if (payload.customerName != null && payload.customerName!.isNotEmpty) {
      bytes += generator.text(
        'Customer: ${payload.customerName}',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.hr(ch: '-');

    // ─── Items ───
    for (final item in payload.items) {
      final qtyStr = item.quantity % 1 == 0
          ? '${item.quantity.toInt()}'
          : '${item.quantity}';

      // Item label and Price
      final itemLabel = '${qtyStr}x ${item.name}';
      final priceStr = _formatCurrency(item.totalPrice);

      bytes += generator.row([
        PosColumn(
          text: itemLabel,
          width: 9,
          styles: const PosStyles(height: PosTextSize.size1),
        ),
        PosColumn(
          text: priceStr,
          width: 3,
          styles: const PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size1,
          ),
        ),
      ]);

      if (item.modifiers.isNotEmpty) {
        final modNames = item.modifiers.map((m) => m.name).join(', ');
        bytes += generator.text('  + $modNames');
      }

      // Note
      if (item.note != null && item.note!.isNotEmpty) {
        bytes += generator.text('  ** ${item.note}');
      }
    }

    bytes += generator.hr(ch: '-');

    // ─── Totals ───
    bytes += generator.row([
      PosColumn(text: 'Subtotal', width: 8),
      PosColumn(
        text: _formatCurrency(payload.subtotal),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    if (payload.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Discount', width: 8),
        PosColumn(
          text: '-${_formatCurrency(payload.discountAmount)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (payload.taxAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Tax', width: 8),
        PosColumn(
          text: _formatCurrency(payload.taxAmount),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (payload.feesAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Service', width: 8),
        PosColumn(
          text: _formatCurrency(payload.feesAmount),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    bytes += generator.hr(ch: '=');
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 8,
        styles: const PosStyles(bold: true, height: PosTextSize.size2),
      ),
      PosColumn(
        text: _formatCurrency(payload.grandTotal),
        width: 4,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
        ),
      ),
    ]);
    bytes += generator.hr(ch: '=');

    // ─── Payment ───
    if (payload.paymentMethod != null) {
      bytes += generator.row([
        PosColumn(text: 'Payment', width: 8),
        PosColumn(
          text: payload.paymentMethod!,
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    final isPaid =
        payload.paymentStatus?.toLowerCase() == 'paid' ||
        payload.paymentStatus?.toLowerCase() == 'lunas' ||
        payload.paymentStatus?.toLowerCase() == 'completed';
    bytes += generator.row([
      PosColumn(text: 'Status', width: 8),
      PosColumn(
        text: isPaid ? 'Lunas' : 'Belum Dibayar',
        width: 4,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    if (payload.payAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Paid', width: 8),
        PosColumn(
          text: _formatCurrency(payload.payAmount),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }
    if (payload.changeAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Change', width: 8),
        PosColumn(
          text: _formatCurrency(payload.changeAmount),
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr(ch: '-');

    final date = payload.date ?? '';
    final cashierName = payload.cashierName ?? '';

    bytes += generator.row([
      PosColumn(text: date, width: 8, styles: const PosStyles(bold: false)),
      PosColumn(
        text: cashierName,
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.feed(1);
    if (!isPaid) {
      bytes += generator.text(
        '** Harap membawa nota ini ketika mengambil pakaian',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.text(
      'Thank you!',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.feed(3);
    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }

  static String _formatCurrency(num amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
