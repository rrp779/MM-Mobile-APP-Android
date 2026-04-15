import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/wishlist_service.dart';

class WishlistProvider extends ChangeNotifier {
  final List<String> _wishlistIds = [];
  final List<Product> _wishlistProducts = [];

  List<String> get wishlistIds => _wishlistIds;
  List<Product> get wishlistProducts => _wishlistProducts;

  bool isInWishlist(String productId) {
    return _wishlistIds.contains(productId);
  }

  Future<void> toggle(String productId) async {
    if (_wishlistIds.contains(productId)) {
      _wishlistIds.remove(productId);
      _wishlistProducts.removeWhere((p) => p.id == productId);
      notifyListeners();
    } else {
      _wishlistIds.add(productId);
      notifyListeners();

      // 🔥 Fetch product from Shopify
      final product = await WishlistService.fetchProductById(productId);

      if (product != null) {
        _wishlistProducts.add(product);
        notifyListeners();
      }
    }
  }

  Future<void> loadWishlist() async {
    _wishlistProducts.clear();

    for (final id in _wishlistIds) {
      final product = await WishlistService.fetchProductById(id);
      if (product != null) {
        _wishlistProducts.add(product);
      }
    }

    notifyListeners();
  }
}