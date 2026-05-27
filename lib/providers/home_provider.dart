import 'dart:async'; // FIXED: Add async import for TimeoutException
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/home_section.dart';
import '../config/backend_config.dart';
import '../models/product.dart';

class HomeProvider extends ChangeNotifier {
  List<HomeSection> _sections = [];
  bool _isLoading = false;
  bool _sectionsLoaded = false;
  // FIXED: Added error state variables
  bool _hasError = false;
  String _errorMessage = '';

  List<HomeSection> get sections => _sections;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError; // FIXED: Added getter
  String get errorMessage => _errorMessage; // FIXED: Added getter

  /// 🔥 CENTRAL PRODUCT CACHE (FIXED: removed final)
  Map<String, Product> _productsMap = {};
  Map<String, Product> get productsMap => _productsMap;

  /// 🔥 TRACK LOADING PRODUCTS
  final Set<String> _loadingProducts = {};

  /* =========================================================
      🔹 FETCH SINGLE PRODUCT
  ========================================================== */

  Future<Product?> fetchSingleProduct(String? productId) async {
    if (productId == null || productId.isEmpty) return null;

    /// ✅ Already cached
    if (_productsMap.containsKey(productId)) {
      return _productsMap[productId];
    }

    /// ✅ Prevent duplicate calls
    if (_loadingProducts.contains(productId)) {
      return null;
    }

    _loadingProducts.add(productId);

    final encodedId = Uri.encodeComponent(productId);
    final url = "${BackendConfig.baseUrl}/products/$encodedId";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data == null || data.isEmpty) return null;

        final product = Product.fromJson(data);

        /// ✅ FIX: replace map (NOT mutate)
        _productsMap = {
          ..._productsMap,
          productId: product,
        };

        notifyListeners(); // 🔥 UI updates instantly

        return product;
      }
    } catch (e) {
      debugPrint("❌ Product fetch error: $e");
    } finally {
      _loadingProducts.remove(productId);
    }

    return null;
  }

  /* =========================================================
      🔥 BULK FETCH
  ========================================================== */

  Future<void> fetchProductsBulk(List<String> ids) async {
    final uniqueIds = ids.toSet();

    final newIds = uniqueIds.where((id) =>
    !_productsMap.containsKey(id) &&
        !_loadingProducts.contains(id)).toList();

    if (newIds.isEmpty) return;

    _loadingProducts.addAll(newIds);

    try {
      final futures = newIds.map((id) async {
        final encodedId = Uri.encodeComponent(id);
        final url = "${BackendConfig.baseUrl}/products/$encodedId";

        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data != null && data.isNotEmpty) {
            return MapEntry(id, Product.fromJson(data));
          }
        }
        return null;
      });

      final results = await Future.wait(futures);

      /// ✅ FIX: batch update map (single rebuild)
      final newData = {
        for (var entry in results)
          if (entry != null) entry.key: entry.value
      };

      if (newData.isNotEmpty) {
        _productsMap = {
          ..._productsMap,
          ...newData,
        };

        notifyListeners(); // 🔥 only once
      }
    } catch (e) {
      debugPrint("❌ Bulk fetch error: $e");
    } finally {
      _loadingProducts.removeAll(newIds);
    }
  }

  /* =========================================================
      🔹 EXTRACT IDS
  ========================================================== */

  List<String> extractAllProductIds() {
    final ids = <String>{};

    for (final section in _sections) {
      for (final item in section.items) {
        if (item.productId != null && item.productId!.isNotEmpty) {
          ids.add(item.productId!);
        }
      }
    }

    return ids.toList();
  }

  /* =========================================================
      🔹 FETCH SECTIONS
  ========================================================== */

  // FIXED: Added optional parameter and comprehensive error handling
  Future<void> fetchSections({bool forceRefresh = false}) async {
    if (_sectionsLoaded && !forceRefresh) return;

    _isLoading = true;
    _hasError = false;
    _errorMessage = '';
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse("${BackendConfig.baseUrl}/sections"),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);

        _sections = data
            .map((e) => HomeSection.fromJson(e))
            .where((section) => section.visible)
            .toList();

        _sectionsLoaded = true;

        /// 🔥 Preload all products
        final ids = extractAllProductIds();
        await fetchProductsBulk(ids); // ✅ IMPORTANT: await
      } else {
        _hasError = true;
        _errorMessage = 'Server error (${response.statusCode}). Pull to retry.';
      }
    } on TimeoutException {
      _hasError = true;
      _errorMessage = 'Connection timed out. Pull to retry.';
    } catch (e) {
      _hasError = true;
      _errorMessage = 'Failed to load. Pull to retry.';
      debugPrint("❌ Sections fetch error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  /* =========================================================
      🔹 CLEAR CACHE
  ========================================================== */

  void clearCache() {
    _productsMap = {}; // ✅ replace, not clear()
    _loadingProducts.clear();
    _sectionsLoaded = false;
    notifyListeners();
  }
}