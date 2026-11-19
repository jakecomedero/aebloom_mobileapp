import 'dart:convert';
import 'package:flutter/material.dart';

AEBloomProducts aeBloomProductsFromJson(String source) =>
    AEBloomProducts.fromJson(json.decode(source) as Map<String, dynamic>);

class AEBloomProducts {
  const AEBloomProducts({required this.data});

  final List<ProductDatum> data;

  factory AEBloomProducts.fromJson(Map<String, dynamic> json) {
    return AEBloomProducts(
      data: (json['data'] as List<dynamic>)
          .map((item) => ProductDatum.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ProductDatum {
  const ProductDatum({
    this.docId,
    required this.id,
    required this.productName,
    required this.flowerType,
    required this.productImage,
    required this.price,
    required this.inStock,
  });

  final String? docId;
  final int id;
  final String productName;
  final String flowerType;
  final String productImage;
  final double price;
  final bool inStock;

  String get firestoreKey => docId ?? id.toString();

  factory ProductDatum.fromJson(Map<String, dynamic> json, {String? docId}) {
    return ProductDatum(
      docId: docId,
      id: (json['id'] as num?)?.toInt() ?? docId.hashCode,
      productName: (json['productName'] as String?) ?? '',
      flowerType: (json['flowerType'] as String?) ?? '',
      productImage: (json['productImage'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      inStock: (json['inStock'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'productName': productName,
        'flowerType': flowerType,
        'productImage': productImage,
        'price': price,
        'inStock': inStock,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductDatum && firestoreKey == other.firestoreKey;

  @override
  int get hashCode => firestoreKey.hashCode;
}

enum OrderStatus {
  preparing('Preparing', Colors.amberAccent),
  ready('Ready', Colors.lightGreenAccent),
  delivered('Delivered', Colors.black12);

  const OrderStatus(this.label, this.color);
  final String label;
  final Color color;

  static OrderStatus fromLabel(String? label) {
    return OrderStatus.values.firstWhere(
      (status) => status.label.toLowerCase() == (label ?? '').toLowerCase(),
      orElse: () => OrderStatus.preparing,
    );
  }
}

class FlowerOrder {
  const FlowerOrder({
    this.docId,
    required this.productName,
    required this.customerName,
    required this.quantity,
    required this.total,
    required this.status,
    required this.createdAt,
  });

  final String? docId;
  final String productName;
  final String customerName;
  final int quantity;
  final double total;
  final OrderStatus status;
  final DateTime createdAt;
}
