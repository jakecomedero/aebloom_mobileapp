import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:ae_bloom/model/aebloom_items.dart';

/// Service handling Cloud Firestore operations for AEBloom.
///
/// Uses the `products` and `orders` top-level collections.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  static const String productsCollection = 'products';
  static const String ordersCollection = 'orders';

  final FirebaseFirestore _db;

  static const List<ProductDatum> _defaultProducts = [
    ProductDatum(
      id: 1,
      productName: 'Red Rose Bouquet',
      flowerType: 'Rose',
      productImage:
          'https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500',
      price: 1800.0,
      inStock: true,
    ),
    ProductDatum(
      id: 2,
      productName: 'Sunflower Bright Box',
      flowerType: 'Sunflower',
      productImage:
          'https://images.unsplash.com/photo-1597848212624-a19eb35e2651?w=500',
      price: 2400.0,
      inStock: true,
    ),
    ProductDatum(
      id: 3,
      productName: 'Pink Tulip Arrangement',
      flowerType: 'Tulip',
      productImage:
          'https://images.unsplash.com/photo-1520763185298-1b434c919102?w=500',
      price: 1950.0,
      inStock: true,
    ),
    ProductDatum(
      id: 4,
      productName: 'White Lily Elegance',
      flowerType: 'Lily',
      productImage:
          'https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11?w=500',
      price: 2200.0,
      inStock: false,
    ),
    ProductDatum(
      id: 5,
      productName: 'Purple Orchid Vase',
      flowerType: 'Orchid',
      productImage:
          'https://images.unsplash.com/photo-1525310072745-f49212b5ac6d?w=500',
      price: 3100.0,
      inStock: true,
    ),
  ];

  /// Real-time stream of all flower products from the `products` collection.
  Stream<List<ProductDatum>> getProductsStream() {
    return _db.collection(productsCollection).snapshots().map((snapshot) {
      final products = snapshot.docs
          .map((doc) => ProductDatum.fromJson(doc.data(), docId: doc.id))
          .toList();
      products.sort((a, b) => a.id.compareTo(b.id));
      return products;
    });
  }

  /// Fetches the current list of products once.
  Future<List<ProductDatum>> getProductsOnce() async {
    final snapshot = await _db.collection(productsCollection).get();
    final products = snapshot.docs
        .map((doc) => ProductDatum.fromJson(doc.data(), docId: doc.id))
        .toList();
    products.sort((a, b) => a.id.compareTo(b.id));
    return products;
  }

  /// Real-time stream of all flower orders from the `orders` collection.
  Stream<List<FlowerOrder>> getOrdersStream() {
    return _db.collection(ordersCollection).snapshots().map((snapshot) {
      final orders = snapshot.docs.map((doc) {
        final data = doc.data();
        final rawCreatedAt = data['createdAt'];
        final createdAt = rawCreatedAt is Timestamp
            ? rawCreatedAt.toDate()
            : DateTime.now();
        return FlowerOrder(
          docId: doc.id,
          productName: (data['productName'] as String?) ?? '',
          customerName: (data['customerName'] as String?) ?? '',
          quantity: (data['quantity'] as num?)?.toInt() ?? 1,
          total: (data['total'] as num?)?.toDouble() ?? 0.0,
          status: OrderStatus.fromLabel(data['status'] as String?),
          createdAt: createdAt,
        );
      }).toList();
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  /// Adds a new flower product to the `products` collection.
  Future<void> addProduct({
    required String productName,
    required String flowerType,
    required String productImage,
    required double price,
    required bool inStock,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch;
    await _db.collection(productsCollection).add({
      'id': id,
      'productName': productName,
      'flowerType': flowerType,
      'productImage': productImage,
      'price': price,
      'inStock': inStock,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Creates or updates a product document in the `products` collection.
  Future<void> saveProduct(ProductDatum product) async {
    final docRef = _db.collection(productsCollection).doc(product.firestoreKey);
    await docRef.set(product.toJson(), SetOptions(merge: true));
  }

  /// Deletes a product document from the `products` collection.
  Future<void> deleteProduct(ProductDatum product) async {
    await _db.collection(productsCollection).doc(product.firestoreKey).delete();
  }

  /// Creates a new order document in the `orders` collection.
  Future<void> createOrder({
    required String productName,
    required String customerName,
    required int quantity,
    required double total,
    OrderStatus status = OrderStatus.preparing,
  }) async {
    await _db.collection(ordersCollection).add({
      'productName': productName,
      'customerName': customerName,
      'quantity': quantity,
      'total': total,
      'status': status.label,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates the status of an existing order in the `orders` collection.
  Future<void> updateOrderStatus(String docId, OrderStatus status) async {
    await _db
        .collection(ordersCollection)
        .doc(docId)
        .update({'status': status.label});
  }

  /// Deletes an order document from the `orders` collection.
  Future<void> deleteOrder(String docId) async {
    await _db.collection(ordersCollection).doc(docId).delete();
  }

  /// Seeds initial products and sample orders if the Firestore collections are empty.
  Future<void> seedInitialData() async {
    await _seedProductsIfEmpty();
    await _seedOrdersIfEmpty();
  }

  Future<void> _seedProductsIfEmpty() async {
    final existing = await _db.collection(productsCollection).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    List<ProductDatum> products = _defaultProducts;
    try {
      final rawJson = await rootBundle.loadString('assets/data/flower.json');
      final parsed = aeBloomProductsFromJson(rawJson).data;
      if (parsed.isNotEmpty) {
        products = parsed;
      }
    } catch (_) {
      // Fall back to embedded product catalog if asset cannot be read.
    }

    final batch = _db.batch();
    for (final product in products) {
      final docRef =
          _db.collection(productsCollection).doc(product.id.toString());
      batch.set(docRef, product.toJson(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> _seedOrdersIfEmpty() async {
    final existing = await _db.collection(ordersCollection).limit(1).get();
    if (existing.docs.isNotEmpty) return;

    final now = DateTime.now();
    final sampleOrders = [
      {
        'productName': 'Red Rose Bouquet',
        'customerName': 'Sarah M.',
        'quantity': 12,
        'total': 1800.0,
        'status': OrderStatus.preparing.label,
        'createdAt': Timestamp.fromDate(now),
      },
      {
        'productName': 'Sunflower Bright Box',
        'customerName': 'Mark T.',
        'quantity': 1,
        'total': 2400.0,
        'status': OrderStatus.ready.label,
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 10))),
      },
      {
        'productName': 'Pink Tulip Arrangement',
        'customerName': 'Anna K.',
        'quantity': 1,
        'total': 1950.0,
        'status': OrderStatus.delivered.label,
        'createdAt':
            Timestamp.fromDate(now.subtract(const Duration(minutes: 20))),
      },
    ];

    final batch = _db.batch();
    for (var i = 0; i < sampleOrders.length; i++) {
      final docRef = _db.collection(ordersCollection).doc('order_${i + 1}');
      batch.set(docRef, sampleOrders[i]);
    }
    await batch.commit();
  }
}
