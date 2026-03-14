import 'package:flutter/services.dart';
import 'package:flutter_thermal_printer/flutter_thermal_printer.dart';
import 'package:image/image.dart' as img;
import '../models/print_job_model.dart';

/// Formats a full receipt for cashier/kasir printers.
class ReceiptFormatter {
  static Future<Uint8List> format(PrintJobPayload payload) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];

    // ─── Top Delimiter ───
    bytes += generator.text(
      '=========================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    // ─── Logo ───
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final Uint8List imageBytes = data.buffer.asUint8List();
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage != null) {
        // resize image if needed, for 58mm printer usually max width is 384
        final img.Image resizedImage = img.copyResize(decodedImage, width: 250);
        bytes += generator.imageRaster(resizedImage, align: PosAlign.center);
      }
    } catch (e) {
      // In case logo fails to load (e.g. not found), ignore safely
    }

    // ─── Dummy Header Texts ───
    bytes += generator.text(
      'EKA PRINT BALI',
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.text(
      'Professional digital printing',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      '=========================================',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(1);

    // ─── Order Info ───
    bytes += generator.text('Kode Order    : ${payload.orderNumber}');
    final dateStr = payload.date ?? '-';
    bytes += generator.text('Tanggal       : $dateStr');
    final kepada = payload.customerName?.isNotEmpty == true
        ? payload.customerName!
        : '-';
    bytes += generator.text('Kepada        : $kepada');
    final kasir = payload.cashierName?.isNotEmpty == true
        ? payload.cashierName!
        : '-';
    bytes += generator.text('Kasir Online  : $kasir');

    bytes += generator.feed(1);
    bytes += generator.text(
      '-----------------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // ─── Items Header ───
    bytes += generator.row([
      PosColumn(text: 'Produk', width: 4, styles: const PosStyles(bold: true)),
      PosColumn(
        text: 'Harga',
        width: 3,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(align: PosAlign.center, bold: true),
      ),
      PosColumn(
        text: 'Total',
        width: 3,
        styles: const PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);
    bytes += generator.text(
      '-----------------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // ─── Items ───
    for (final item in payload.items) {
      final qtyStr = item.quantity % 1 == 0
          ? '${item.quantity.toInt()}'
          : '${item.quantity}';

      bytes += generator.row([
        PosColumn(text: item.name, width: 4),
        PosColumn(
          text: _formatCurrency(item.pricePerItem),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: qtyStr,
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: _formatCurrency(item.totalPrice),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      // Modifiers
      if (item.modifiers.isNotEmpty) {
        for (var mod in item.modifiers) {
          bytes += generator.text('- ${mod.name}');
        }
      }

      // Note
      if (item.note != null && item.note!.isNotEmpty) {
        bytes += generator.text('  * ${item.note}');
      }

      bytes += generator.feed(1);
    }

    bytes += generator.text(
      '-----------------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // ─── Totals ───
    bytes += generator.row([
      PosColumn(text: '', width: 5),
      PosColumn(
        text: 'Total  :',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
      PosColumn(
        text: _formatCurrency(payload.grandTotal),
        width: 3,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // Add discount if there is any
    if (payload.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: '', width: 5),
        PosColumn(
          text: 'Diskon :',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: '-${_formatCurrency(payload.discountAmount)}',
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: '', width: 5),
      PosColumn(
        text: 'Bayar  :',
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
      PosColumn(
        text: _formatCurrency(payload.payAmount),
        width: 3,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.feed(1);

    // ─── Payment Status ───
    final paymentStatus = payload.paymentStatus ?? 'LUNAS';
    bytes += generator.text('Keterangan : $paymentStatus');

    bytes += generator.feed(1);

    // ─── Footer ───
    bytes += generator.text(
      'TERIMA KASIH',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );
    bytes += generator.text(
      'Ekaprint Central',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Jl. Hayam Wuruk, No. 185 A',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'WA: 085337932762',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(1);

    // ─── Terms ───
    bytes += generator.text(
      '"Batas pengambilan orderan maksimum 3 bulan\nsejak nota dikeluarkan. Produk rusak akan\ndiganti. Klaim kerusakan wajib disertai\nvideo unboxing (maks. 1x24 jam)."',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      '=========================================',
      styles: const PosStyles(align: PosAlign.center),
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
