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

    // ─── Logo ───
    try {
      final ByteData data = await rootBundle.load('assets/images/logo.png');
      final Uint8List imageBytes = data.buffer.asUint8List();
      final img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage != null) {
        final img.Image resizedImage = img.copyResize(
          decodedImage,
          width: 250,
        ); // Sedikit diperbesar agar pas
        bytes += generator.image(resizedImage, align: PosAlign.center);
      }
    } catch (e) {
      print('⚠️ Failed to load or print logo: $e');
      // Fallback teks jika logo gagal
      bytes += generator.text(
        'EKA PRINT',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }

    // ─── Tagline ───
    bytes += generator.text(
      'Professional digital printing',
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.feed(1);

    // ─── Order Info ───
    // Menggunakan padding manual agar titik dua (:) rata
    bytes += generator.text('Kode Order    : ${payload.orderNumber}');
    bytes += generator.text('Tanggal       : ${payload.date ?? '-'}');
    // Pastikan tambahkan properti deadline di model PrintJobPayload kamu
    bytes += generator.text('Deadline      : ${'-'}');

    final kepada = payload.customerName?.isNotEmpty == true
        ? payload.customerName!
        : '-';
    bytes += generator.text('Kepada        : $kepada');

    final kasir = payload.cashierName?.isNotEmpty == true
        ? payload.cashierName!
        : '-';
    bytes += generator.text('Kasir Offline : $kasir');

    bytes += generator.feed(1);

    // ─── Items Header ───
    // Lebar total harus 12
    bytes += generator.row([
      PosColumn(text: 'Produk', width: 4), // Normal text di header
      PosColumn(
        text: 'Harga',
        width: 3,
        styles: const PosStyles(align: PosAlign.right),
      ),
      PosColumn(
        text: 'Qty',
        width: 2,
        styles: const PosStyles(align: PosAlign.center),
      ),
      PosColumn(
        text: 'Total',
        width: 3,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // ─── Items ───
    for (final item in payload.items) {
      final qtyStr = item.quantity % 1 == 0
          ? '${item.quantity.toInt()}'
          : '${item.quantity}';

      bytes += generator.row([
        // Nama produk cetak tebal (bold) sesuai gambar
        PosColumn(
          text: item.name,
          width: 5,
          styles: const PosStyles(bold: true),
        ),
        PosColumn(
          text: _formatCurrency(item.pricePerItem),
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: qtyStr,
          width: 1,
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
        bytes += generator.text('- ${item.note}');
      }

      bytes += generator.feed(1); // Jarak antar item
    }

    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // ─── Totals ───
    bytes += generator.row([
      PosColumn(text: '', width: 5),
      PosColumn(
        text: 'Total :',
        width: 3,
        styles: const PosStyles(align: PosAlign.right),
      ),
      PosColumn(
        text: _formatCurrency(payload.grandTotal),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // Add discount if there is any
    if (payload.discountAmount > 0) {
      bytes += generator.row([
        PosColumn(text: '', width: 5),
        PosColumn(
          text: 'Diskon :',
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
        PosColumn(
          text: '-${_formatCurrency(payload.discountAmount)}',
          width: 4,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.row([
      PosColumn(text: '', width: 5),
      PosColumn(
        text: 'Bayar :',
        width: 3,
        styles: const PosStyles(align: PosAlign.right),
      ),
      PosColumn(
        text: _formatCurrency(payload.payAmount),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.feed(1);

    // ─── Payment Status ───
    // Teks LUNAS dibuat membesar sesuai dengan foto struk
    final paymentStatus = payload.paymentStatus ?? 'LUNAS';
    bytes += generator.row([
      PosColumn(
        text: 'Keterangan : ',
        width: 5,
        styles: const PosStyles(align: PosAlign.left),
      ),
      PosColumn(
        text: paymentStatus,
        width: 7,
        styles: const PosStyles(
          align: PosAlign.left,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]);

    bytes += generator.feed(1);

    // ─── Footer ───
    bytes += generator.text(
      'TERIMA KASIH',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Ekaprint Panjer',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Jl. Waturenggong No.64, Panjer,',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Kec. Denpasar Selatan',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Kota Denpasar, Bali 80113',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'WA: 081246278452',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(1);

    // ─── Terms ───
    bytes += generator.text(
      '"Batas pengambilan orderan maksimum 3 bulan sejak nota dikeluarkan. Produk rusak akan diganti. Klaim kerusakan wajib disertai video unboxing (maks. 1x24 jam)."',
      styles: const PosStyles(align: PosAlign.left),
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
