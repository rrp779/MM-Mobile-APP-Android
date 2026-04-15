import 'package:flutter/material.dart';
import '../models/product.dart';
import '../models/collection.dart';

class ProductProvider extends ChangeNotifier {
  final Map<String, Product> _products = {};
  final Map<String, CollectionModel> _brands = {};

  List<Product> get products => _products.values.toList();

  // 🔥 Add products
  void addProducts(List<Product> newProducts) {
    for (final product in newProducts) {
      _products[product.id] = product;
    }
    notifyListeners();
  }

  Product? getById(String id) {
    return _products[id];
  }

  // 🔥 STORE BRANDS
  void setBrands(List<CollectionModel> brands) {
    for (final brand in brands) {
      _brands[brand.handle] = brand;
    }
  }

  // 🔥 GET BRAND NAME BY COLLECTION HANDLE
  String? getBrandName(String collectionHandle) {
    return _brands[collectionHandle]?.title;
  }

  // 🔥 CHECK IF HANDLE IS BRAND
  bool isBrand(String collectionHandle) {
    return _brands.containsKey(collectionHandle);
  }
}