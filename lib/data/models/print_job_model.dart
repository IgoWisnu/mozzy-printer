import 'package:flutter/foundation.dart';

class PrintJobItem {
  final String name;
  final num quantity;
  final num pricePerItem;
  final num totalPrice;
  final String? note;

  PrintJobItem({
    required this.name,
    required this.quantity,
    required this.pricePerItem,
    required this.totalPrice,
    this.note,
  });

  factory PrintJobItem.fromJson(Map<String, dynamic> json) {
    // qty can be String "1.00" or num
    num qty;
    final rawQty = json['qty'] ?? json['quantity'] ?? 1;
    if (rawQty is String) {
      qty = num.tryParse(rawQty) ?? 1;
    } else {
      qty = rawQty as num;
    }

    return PrintJobItem(
      name: (json['name'] ?? json['itemName'] ?? 'Unknown') as String,
      quantity: qty,
      pricePerItem: (json['pricePerItem'] ?? json['price'] ?? 0) as num,
      totalPrice: (json['totalPrice'] ?? json['total_price'] ?? 0) as num,
      note: (json['note'] ?? json['notes']) as String?,
    );
  }
}

class PrintJobPayload {
  // Business / Store info
  final String? businessName;
  final String? businessLogo;
  final String? storeName;
  final String? storeAddress;
  final String? storePhone;

  // Order info
  final String orderNumber;
  final String? customerName;
  final String? date;
  final String? cashierName;
  final bool isDineIn;
  final String? table;
  final int queueNumber;

  // Items
  final List<PrintJobItem> items;

  // Totals
  final num subtotal;
  final num taxAmount;
  final num feesAmount;
  final num grandTotal;

  // Payment
  final String? paymentMethod;
  final num payAmount;
  final num changeAmount;
  final String? paymentStatus;

  // Print area (may or may not be in payload)
  final String printArea;

  PrintJobPayload({
    this.businessName,
    this.businessLogo,
    this.storeName,
    this.storeAddress,
    this.storePhone,
    required this.orderNumber,
    this.customerName,
    this.date,
    this.cashierName,
    this.isDineIn = false,
    this.table,
    required this.queueNumber,
    required this.items,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.feesAmount = 0,
    this.grandTotal = 0,
    this.paymentMethod,
    this.payAmount = 0,
    this.changeAmount = 0,
    this.paymentStatus,
    this.printArea = '',
  });

  factory PrintJobPayload.fromJson(Map<String, dynamic> json) {
    debugPrint('📦 Parsing payload keys: ${json.keys.toList()}');

    // Parse queueNumber — can be int or String
    int queueNum;
    final rawQueue = json['queueNumber'] ?? json['queue_number'] ?? 0;
    if (rawQueue is String) {
      queueNum = int.tryParse(rawQueue) ?? 0;
    } else {
      queueNum = (rawQueue as num).toInt();
    }

    return PrintJobPayload(
      businessName: json['businessName'] as String?,
      businessLogo: json['businessLogo'] as String?,
      storeName: json['storeName'] as String?,
      storeAddress: json['storeAddress'] as String?,
      storePhone: json['storePhone'] as String?,
      orderNumber: '${json['orderNumber'] ?? json['order_number'] ?? ''}',
      customerName: json['customerName'] as String?,
      date: json['date'] as String?,
      cashierName: json['cashierName'] as String?,
      isDineIn: json['isDineIn'] as bool? ?? false,
      table: json['table'] != null ? '${json['table']}' : null,
      queueNumber: queueNum,
      items: json['items'] != null
          ? (json['items'] as List<dynamic>)
                .map(
                  (e) => PrintJobItem.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : [],
      subtotal: (json['subtotal'] ?? 0) as num,
      taxAmount: (json['taxAmount'] ?? 0) as num,
      feesAmount: (json['feesAmount'] ?? 0) as num,
      grandTotal: (json['grandTotal'] ?? 0) as num,
      paymentMethod: json['paymentMethod'] as String?,
      payAmount: (json['payAmount'] ?? 0) as num,
      changeAmount: (json['changeAmount'] ?? 0) as num,
      paymentStatus: json['paymentStatus'] as String?,
      printArea: (json['print_area'] ?? json['printArea'] ?? '') as String,
    );
  }
}

enum PrintJobStatus { pending, printing, success, failed }

class PrintJobModel {
  final int id;
  final int orderId;
  final String printArea;
  final int retryCount;
  final PrintJobPayload payload;
  PrintJobStatus status;
  String? errorMessage;
  final DateTime receivedAt;

  PrintJobModel({
    required this.id,
    required this.orderId,
    required this.printArea,
    required this.retryCount,
    required this.payload,
    this.status = PrintJobStatus.pending,
    this.errorMessage,
    DateTime? receivedAt,
  }) : receivedAt = receivedAt ?? DateTime.now();

  factory PrintJobModel.fromSocketData(Map<String, dynamic> data) {
    debugPrint('📦 Parsing print job keys: ${data.keys.toList()}');

    final rawPayload = data['payload'];
    Map<String, dynamic> payloadMap;
    if (rawPayload is Map) {
      payloadMap = Map<String, dynamic>.from(rawPayload);
    } else {
      payloadMap = data;
    }

    int jobId;
    final rawId = data['id'] ?? 0;
    if (rawId is String) {
      jobId = int.tryParse(rawId) ?? 0;
    } else {
      jobId = (rawId as num).toInt();
    }

    int orderId;
    final rawOrderId = data['orderId'] ?? data['order_id'] ?? 0;
    if (rawOrderId is String) {
      orderId = int.tryParse(rawOrderId) ?? 0;
    } else {
      orderId = (rawOrderId as num).toInt();
    }

    return PrintJobModel(
      id: jobId,
      orderId: orderId,
      printArea: (data['printArea'] ?? data['print_area'] ?? '') as String,
      retryCount: (data['retryCount'] ?? data['retry_count'] ?? 0) as int? ?? 0,
      payload: PrintJobPayload.fromJson(payloadMap),
    );
  }
}
