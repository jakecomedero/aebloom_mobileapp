import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ae_bloom/model/aebloom_items.dart';

/// Service API Controller handling HTTP GET, POST, PUT, and DELETE operations.
class AEBloomApi {
  AEBloomApi({http.Client? client}) : _client = client ?? http.Client();

  static final Uri endpoint = Uri.parse(
    'https://gist.githubusercontent.com/jakecomedero/'
    'ca5720d38d201abbd48b6bde6c915730/raw/'
    'f8dc38c28ec525517142978b673e8de65fdff4da/flower.json',
  );

  final http.Client _client;

  static const String _fallbackProductsJson = '''
  {
    "data": [
      {
        "id": 1,
        "productName": "Red Rose Bouquet",
        "flowerType": "Rose",
        "productImage": "https://images.unsplash.com/photo-1518709268805-4e9042af9f23?w=500",
        "price": 1800.0,
        "inStock": true
      },
      {
        "id": 2,
        "productName": "Sunflower Bright Box",
        "flowerType": "Sunflower",
        "productImage": "https://images.unsplash.com/photo-1597848212624-a19eb35e2651?w=500",
        "price": 2400.0,
        "inStock": true
      },
      {
        "id": 3,
        "productName": "Pink Tulip Arrangement",
        "flowerType": "Tulip",
        "productImage": "https://images.unsplash.com/photo-1520763185298-1b434c919102?w=500",
        "price": 1950.0,
        "inStock": true
      },
      {
        "id": 4,
        "productName": "White Lily Elegance",
        "flowerType": "Lily",
        "productImage": "https://images.unsplash.com/photo-1582794543139-8ac9cb0f7b11?w=500",
        "price": 2200.0,
        "inStock": false
      },
      {
        "id": 5,
        "productName": "Purple Orchid Vase",
        "flowerType": "Orchid",
        "productImage": "https://images.unsplash.com/photo-1525310072745-f49212b5ac6d?w=500",
        "price": 3100.0,
        "inStock": true
      }
    ]
  }
  ''';

  // 1. HTTP GET Request
  Future<AEBloomProducts> getProducts() async {
    try {
      final response = await _client.get(endpoint);
      if (response.statusCode == 200) {
        return aeBloomProductsFromJson(response.body);
      } else {
        return aeBloomProductsFromJson(_fallbackProductsJson);
      }
    } catch (e) {
      return aeBloomProductsFromJson(_fallbackProductsJson);
    }
  }

  // 2. HTTP POST Request
  Future<bool> createProduct(ProductDatum newProduct) async {
    try {
      final response = await _client.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': newProduct.id,
          'productName': newProduct.productName,
          'flowerType': newProduct.flowerType,
          'productImage': newProduct.productImage,
          'price': newProduct.price,
          'inStock': newProduct.inStock,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // 3. HTTP PUT Request
  Future<bool> updateProduct(int id, ProductDatum updatedProduct) async {
    try {
      final updateUri = Uri.parse('${endpoint.toString()}/$id');
      final response = await _client.put(
        updateUri,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': updatedProduct.id,
          'productName': updatedProduct.productName,
          'flowerType': updatedProduct.flowerType,
          'productImage': updatedProduct.productImage,
          'price': updatedProduct.price,
          'inStock': updatedProduct.inStock,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // 4. HTTP DELETE Request
  Future<bool> deleteProduct(int id) async {
    try {
      final deleteUri = Uri.parse('${endpoint.toString()}/$id');
      final response = await _client.delete(deleteUri);
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }
}