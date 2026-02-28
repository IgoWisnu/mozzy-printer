import 'dart:convert';

enum PrinterConnectionType { bluetooth, usb }

class PrinterModel {
  final String id;
  final String name;
  final String address;
  final String printArea;
  final PrinterConnectionType connectionType;
  bool isConnected;

  PrinterModel({
    required this.id,
    required this.name,
    required this.address,
    required this.printArea,
    required this.connectionType,
    this.isConnected = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'printArea': printArea,
    'connectionType': connectionType.toString().split('.').last,
    'isConnected': isConnected,
  };

  factory PrinterModel.fromJson(Map<String, dynamic> json) => PrinterModel(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    printArea: json['printArea'] as String,
    connectionType: PrinterConnectionType.values.firstWhere(
      (e) => e.toString().split('.').last == json['connectionType'],
      orElse: () => PrinterConnectionType.bluetooth,
    ),
    isConnected: json['isConnected'] as bool? ?? false,
  );

  String toJsonString() => jsonEncode(toJson());

  factory PrinterModel.fromJsonString(String source) =>
      PrinterModel.fromJson(jsonDecode(source) as Map<String, dynamic>);

  PrinterModel copyWith({
    String? id,
    String? name,
    String? address,
    String? printArea,
    PrinterConnectionType? connectionType,
    bool? isConnected,
  }) => PrinterModel(
    id: id ?? this.id,
    name: name ?? this.name,
    address: address ?? this.address,
    printArea: printArea ?? this.printArea,
    connectionType: connectionType ?? this.connectionType,
    isConnected: isConnected ?? this.isConnected,
  );

  @override
  String toString() =>
      'PrinterModel(id: $id, name: $name, printArea: $printArea, '
      'connectionType: ${connectionType.toString().split('.').last}, connected: $isConnected)';
}
