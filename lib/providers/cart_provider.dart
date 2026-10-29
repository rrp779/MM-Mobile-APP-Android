import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/shopify_client.dart';

class CartProvider with ChangeNotifier {
  static const String _storageCartIdKey = 'shopify_cart_id';
  static const String _storageCartCacheKey = 'shopify_cart_cache';

  String? _cartId;
  String? _checkoutUrl;

  List<Map<String, dynamic>> _lines = [];

  bool _isLoading = false;

  CartProvider() {
    loadCartFromStorage();
  }

  /// ---------------- GETTERS ----------------

  String? get checkoutUrl => _checkoutUrl;

  List<Map<String, dynamic>> get lines => _lines;

  bool get isLoading => _isLoading;

  int get totalQuantity {
    int total = 0;
    for (var line in _lines) {
      total += line['quantity'] as int;
    }
    return total;
  }

  double get totalAmount {
    double total = 0;
    for (var line in _lines) {
      final price = double.tryParse(
          line['merchandise']['price']['amount'].toString()) ??
          0;
      total += price * (line['quantity'] as int);
    }
    return total;
  }

  bool containsVariant(String variantId) {
    return _lines.any(
          (line) => line['merchandise']['id'] == variantId,
    );
  }

  /// ---------------- PERSISTENCE & SYNC ----------------

  Future<void> _saveCartToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_cartId != null && _lines.isNotEmpty) {
        await prefs.setString(_storageCartIdKey, _cartId!);
        await prefs.setString(
          _storageCartCacheKey,
          jsonEncode({
            'cartId': _cartId,
            'checkoutUrl': _checkoutUrl,
            'lines': _lines,
            'appliedCoupon': _appliedCoupon,
            'couponDiscount': _couponDiscount,
          }),
        );
      } else if (_lines.isEmpty) {
        await prefs.remove(_storageCartIdKey);
        await prefs.remove(_storageCartCacheKey);
      }
    } catch (e) {
      debugPrint('Error saving cart to storage: $e');
    }
  }

  Future<void> _clearCartStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageCartIdKey);
      await prefs.remove(_storageCartCacheKey);
    } catch (e) {
      debugPrint('Error clearing cart storage: $e');
    }
  }

  Future<void> loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCartId = prefs.getString(_storageCartIdKey);
      final cachedData = prefs.getString(_storageCartCacheKey);

      if (savedCartId != null && savedCartId.isNotEmpty) {
        _cartId = savedCartId;

        // 1. Immediately restore state from cache for zero-latency UI
        if (cachedData != null) {
          try {
            final decoded = jsonDecode(cachedData) as Map<String, dynamic>;
            _checkoutUrl = decoded['checkoutUrl'] as String?;
            _appliedCoupon = decoded['appliedCoupon'] as String?;
            _couponDiscount =
                (decoded['couponDiscount'] as num?)?.toDouble() ?? 0;
            if (decoded['lines'] is List) {
              _lines = (decoded['lines'] as List)
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
            }
            notifyListeners();
          } catch (e) {
            debugPrint('Error restoring cached cart data: $e');
          }
        }

        // 2. Fetch fresh cart state from Shopify in background
        await fetchCart();
      }
    } catch (e) {
      debugPrint('Error loading cart from storage: $e');
    }
  }

  Future<void> fetchCart() async {
    if (_cartId == null) return;

    try {
      final client = getShopifyClient();
      const query = r'''
      query GetCart($cartId: ID!) {
        cart(id: $cartId) {
          id
          checkoutUrl
          lines(first: 50) {
            edges {
              node {
                id
                quantity
                merchandise {
                  ... on ProductVariant {
                    id
                    title
                    image { url }
                    product { title handle }
                    price { amount }
                    compareAtPrice { amount }
                    quantityAvailable
                  }
                }
              }
            }
          }
          discountCodes {
            code
            applicable
          }
          discountAllocations {
            discountedAmount { amount }
            ... on CartCodeDiscountAllocation {
              code
            }
          }
          cost {
            subtotalAmount { amount }
            totalAmount { amount }
          }
        }
      }
      ''';

      final result = await client.query(
        QueryOptions(
          document: gql(query),
          variables: {"cartId": _cartId},
          fetchPolicy: FetchPolicy.networkOnly,
        ),
      );

      if (result.hasException) {
        debugPrint("Error fetching cart from Shopify: ${result.exception}");
        return;
      }

      final cart = result.data?['cart'];
      if (cart == null) {
        // Cart expired or does not exist on Shopify
        resetCartState();
      } else {
        _updateCartFromResponse(cart);
      }
    } catch (e) {
      debugPrint("Exception fetching cart: $e");
    }
  }

  /// ---------------- CREATE CART ----------------

  Future<void> _createCart() async {
    final client = getShopifyClient();

    const mutation = r'''
    mutation {
      cartCreate {
        cart {
          id
          checkoutUrl
        }
      }
    }
    ''';

    final result = await client.mutate(
      MutationOptions(document: gql(mutation)),
    );

    if (result.hasException) {
      debugPrint(result.exception.toString());
      return;
    }

    final cart = result.data!['cartCreate']['cart'];

    _cartId = cart['id'];
    _checkoutUrl = cart['checkoutUrl'];

    await _saveCartToStorage();
    notifyListeners();
  }

  /// ---------------- ADD TO CART ----------------

  Future<String?> addToCart({
    required String variantId,
    int quantity = 1,
  }) async {
    if (_cartId == null) {
      await _createCart();
    }

    if (_cartId == null) return "Failed to initialize cart";

    if (variantId.contains("68045778157872")) {
      return "Promotional gifts cannot be added directly to cart";
    }

    final existingLine = _lines
        .where((line) => line['merchandise']['id'] == variantId)
        .toList();

    if (existingLine.isNotEmpty) {
      final merch = existingLine.first['merchandise'];
      final int? available =
          merch != null ? (merch['quantityAvailable'] as int?) : null;
      final int currentQty = existingLine.first['quantity'] as int;
      if (available != null && (currentQty + quantity) > available) {
        return "Only $available item${available == 1 ? '' : 's'} available in stock";
      }
      return await updateQuantity(
        lineId: existingLine.first['id'],
        quantity: currentQty + quantity,
      );
    }

    _isLoading = true;
    notifyListeners();

    final client = getShopifyClient();

    const mutation = r'''
    mutation AddToCart($cartId: ID!, $lines: [CartLineInput!]!) {
      cartLinesAdd(cartId: $cartId, lines: $lines) {
        cart {
          id
          checkoutUrl
          lines(first: 50) {
            edges {
              node {
                id
                quantity
                merchandise {
                  ... on ProductVariant {
                    id
                    title
                    image { url }
                    product { title handle }
                    price { amount }
                    compareAtPrice { amount }
                    quantityAvailable
                  }
                }
              }
            }
          }
        }
        userErrors {
          message
          code
        }
        warnings {
          code
          message
        }
      }
    }
    ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "cartId": _cartId,
          "lines": [
            {
              "merchandiseId": variantId,
              "quantity": quantity,
            }
          ],
        },
      ),
    );

    if (result.hasException || result.data?['cartLinesAdd']?['cart'] == null) {
      debugPrint("addToCart error: ${result.exception}");
      // If the cart on Shopify has expired or is invalid, re-create and retry once
      _cartId = null;
      await _clearCartStorage();
      await _createCart();
      if (_cartId != null) {
        final retryResult = await client.mutate(
          MutationOptions(
            document: gql(mutation),
            variables: {
              "cartId": _cartId,
              "lines": [
                {
                  "merchandiseId": variantId,
                  "quantity": quantity,
                }
              ],
            },
          ),
        );
        final retryPayload = retryResult.data?['cartLinesAdd'];
        if (retryPayload?['cart'] != null) {
          _updateCartFromResponse(retryPayload['cart']);
          final warnings = retryPayload['warnings'] as List?;
          if (warnings != null && warnings.isNotEmpty) {
            for (final w in warnings) {
              if (w['code'] == 'MERCHANDISE_NOT_ENOUGH_STOCK') {
                return w['message']?.toString();
              }
            }
          }
          return null;
        }
      }
      _isLoading = false;
      notifyListeners();
      return "Unable to add product to cart";
    }

    final payload = result.data?['cartLinesAdd'];
    final userErrors = payload?['userErrors'] as List?;
    if (userErrors != null && userErrors.isNotEmpty) {
      _isLoading = false;
      notifyListeners();
      return userErrors.first['message']?.toString() ?? "Unable to add item";
    }

    _updateCartFromResponse(payload['cart']);

    final warnings = payload?['warnings'] as List?;
    if (warnings != null && warnings.isNotEmpty) {
      for (final w in warnings) {
        if (w['code'] == 'MERCHANDISE_NOT_ENOUGH_STOCK') {
          return w['message']?.toString();
        }
      }
    }

    return null;
  }

  /// ---------------- UPDATE QUANTITY ----------------

  Future<String?> updateQuantity({
    required String lineId,
    required int quantity,
  }) async {
    if (_cartId == null) return null;

    final existingLine = _lines.where((line) => line['id'] == lineId).toList();
    if (existingLine.isNotEmpty) {
      final merch = existingLine.first['merchandise'];
      final int? available =
          merch != null ? (merch['quantityAvailable'] as int?) : null;
      if (available != null && quantity > available) {
        return "Only $available item${available == 1 ? '' : 's'} available in stock";
      }
    }

    _isLoading = true;
    notifyListeners();

    final client = getShopifyClient();

    const mutation = r'''
  mutation UpdateCart($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
    cartLinesUpdate(cartId: $cartId, lines: $lines) {
      cart {
        id
        checkoutUrl
        lines(first: 50) {
          edges {
            node {
              id
              quantity
              merchandise {
                ... on ProductVariant {
                  id
                  title
                  image { url }
                  product { title handle }
                  price { amount }
                  compareAtPrice { amount }
                  quantityAvailable
                }
              }
            }
          }
        }
      }
      userErrors {
        field
        message
        code
      }
      warnings {
        code
        message
      }
    }
  }
  ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "cartId": _cartId,
          "lines": [
            {
              "id": lineId,
              "quantity": quantity,
            }
          ],
        },
      ),
    );

    if (result.hasException) {
      debugPrint(result.exception.toString());
      _isLoading = false;
      notifyListeners();
      return "Network error updating quantity";
    }

    final payload = result.data?['cartLinesUpdate'];
    final userErrors = payload?['userErrors'] as List?;
    if (userErrors != null && userErrors.isNotEmpty) {
      _isLoading = false;
      notifyListeners();
      return userErrors.first['message']?.toString() ?? "Could not update quantity";
    }

    final warnings = payload?['warnings'] as List?;
    String? stockWarning;
    if (warnings != null && warnings.isNotEmpty) {
      for (final w in warnings) {
        if (w['code'] == 'MERCHANDISE_NOT_ENOUGH_STOCK') {
          stockWarning = w['message']?.toString();
          break;
        }
      }
    }

    if (payload?['cart'] != null) {
      _updateCartFromResponse(payload['cart']);
    } else {
      _isLoading = false;
      notifyListeners();
    }

    return stockWarning;
  }

  /// ---------------- REMOVE ITEM ----------------

  Future<void> removeItem(String lineId) async {
    if (_cartId == null) return;

    _isLoading = true;
    notifyListeners();

    final client = getShopifyClient();

    const mutation = r'''
  mutation RemoveItem($cartId: ID!, $lineIds: [ID!]!) {
    cartLinesRemove(cartId: $cartId, lineIds: $lineIds) {
      cart {
        id
        checkoutUrl
        lines(first: 50) {
          edges {
            node {
              id
              quantity
              merchandise {
                ... on ProductVariant {
                  id
                  title
                  image { url }
                  product { title handle }
                  price { amount }
                  compareAtPrice { amount }
                  quantityAvailable
                }
              }
            }
          }
        }
      }
    }
  }
  ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "cartId": _cartId,
          "lineIds": [lineId],
        },
      ),
    );

    if (result.hasException) {
      debugPrint(result.exception.toString());
      _isLoading = false;
      notifyListeners();
      return;
    }

    _updateCartFromResponse(
        result.data!['cartLinesRemove']['cart']);
  }

  /// ---------------- CLEAR CART ----------------

  Future<void> clearCart() async {
    final ids = _lines.map((e) => e['id']).toList();
    for (var id in ids) {
      await removeItem(id);
    }
    if (_lines.isEmpty) {
      await _clearCartStorage();
    }
  }

  /// ---------------- HELPER ----------------

  void _updateCartFromResponse(Map<String, dynamic> cart) {
    if (cart['id'] != null) {
      _cartId = cart['id'].toString();
    }
    _checkoutUrl = cart['checkoutUrl'];

    if (cart['lines'] != null && cart['lines']['edges'] != null) {
      _lines = (cart['lines']['edges'] as List)
          .map((e) => e['node'] as Map<String, dynamic>)
          .toList();
    }

    _syncCouponStateFromCart(cart);

    _isLoading = false;
    notifyListeners();
    _saveCartToStorage();
  }

  double get totalMrp {
    double total = 0;

    for (var line in _lines) {
      final compareAtRaw =
      line['merchandise']['compareAtPrice']?['amount'];

      final price =
          double.tryParse(
              line['merchandise']['price']['amount']
                  .toString()) ??
              0;

      final quantity = line['quantity'] as int;

      if (compareAtRaw != null) {
        final compareAt =
            double.tryParse(compareAtRaw) ?? price;
        total += compareAt * quantity;
      } else {
        total += price * quantity;
      }
    }

    return total;
  }

  double get totalSellingPrice {
    double total = 0;

    for (var line in _lines) {
      final price =
          double.tryParse(
              line['merchandise']['price']['amount']
                  .toString()) ??
              0;

      total += price * (line['quantity'] as int);
    }

    return total;
  }

  double get totalDiscount {
    return totalMrp - totalSellingPrice;
  }

  /// ---------------- AUTOMATIC PROMOTIONS & GIFTS ----------------

  static const Set<String> hnkToolVariantIds = {
    "49634701115696", "49634736374064", "49634794635568", "49634910142768",
    "49634923020592", "49634924134704", "49634925510960", "49634929639728",
    "49634929672496", "49635038331184", "49635038363952", "49635038396720",
    "49635038429488", "49635038462256", "49635061924144", "49635101901104",
    "49635127460144", "49635127492912", "49635140600112", "49635156132144",
    "49635159769392", "49635163799856", "49635172843824", "49635172876592",
    "49635172909360", "49635172942128", "49635187818800", "49635191521584",
    "49635191554352", "49635193749808", "49635291070768", "50461786439984",
    "50461799776560", "50461805904176", "66739417088304", "66739523420464",
    "66739534201136", "67570488639792"
  };

  static const String hnkPaddleBrushVariantId = "49634937995568";

  static const Set<String> bbCreamVariantIds = {
    "67720111882544", "67720111915312", "67720111948080",
    "67720111980848", "67720112013616", "67720112046384"
  };

  static const Set<String> kajalVariantIds = {
    // Gorgeous Girl Automatic Kajal Pencil with One Stroke Smooth Glide (₹299)
    "67720339423536", "67720339456304",
    // Gorgeous Girl Kohl kajal with One Stroke Smooth Glide (₹499)
    "67744379076912",
    // Gorgeous Girl Pro 1 Stroke Stay-On Kohl Pencil – Waterproof Long Lasting Kajal (₹449)
    "67745185628464", "67745185661232", "67745185694000", "67745185726768", "67745185759536"
  };

  String _extractNumericId(String? raw) {
    if (raw == null) return "";
    final parts = raw.split('/');
    final lastPart = parts.last.split('?').first;
    final match = RegExp(r'\d+').firstMatch(lastPart);
    return match?.group(0) ?? raw;
  }

  double get promotionalDiscount {
    double discount = 0;

    bool hasHnkTool = false;
    double paddleBrushPrice = 0;
    int paddleBrushQty = 0;

    for (var line in _lines) {
      final merch = line['merchandise'];
      final numId = _extractNumericId(merch?['id']?.toString());
      final qty = (line['quantity'] as int?) ?? 1;
      final price = double.tryParse(merch?['price']?['amount']?.toString() ?? '0') ?? 0;

      if (hnkToolVariantIds.contains(numId)) {
        hasHnkTool = true;
      } else if (numId == hnkPaddleBrushVariantId) {
        paddleBrushQty += qty;
        paddleBrushPrice = price;
      }
    }

    if (hasHnkTool && paddleBrushQty > 0) {
      discount += paddleBrushPrice;
    }

    // BB Cream (Buy 1 Get 2 Free)
    List<double> bbPrices = [];
    for (var line in _lines) {
      final merch = line['merchandise'];
      final numId = _extractNumericId(merch?['id']?.toString());
      final qty = (line['quantity'] as int?) ?? 1;
      final price = double.tryParse(merch?['price']?['amount']?.toString() ?? '1099') ?? 1099;
      if (bbCreamVariantIds.contains(numId)) {
        for (int i = 0; i < qty; i++) {
          bbPrices.add(price);
        }
      }
    }
    if (bbPrices.length >= 3) {
      bbPrices.sort(); // cheapest units first
      int count = bbPrices.length;
      int completedBundles = count ~/ 3;
      int freeItemsCount = completedBundles * 2;
      for (int i = 0; i < freeItemsCount && i < bbPrices.length; i++) {
        discount += bbPrices[i];
      }
    }

    // Kajal (Buy 1 Get 2 Free)
    List<double> kajalPrices = [];
    for (var line in _lines) {
      final merch = line['merchandise'];
      final numId = _extractNumericId(merch?['id']?.toString());
      final qty = (line['quantity'] as int?) ?? 1;
      final price = double.tryParse(merch?['price']?['amount']?.toString() ?? '299') ?? 299;
      if (kajalVariantIds.contains(numId)) {
        for (int i = 0; i < qty; i++) {
          kajalPrices.add(price);
        }
      }
    }
    if (kajalPrices.length >= 3) {
      kajalPrices.sort(); // cheapest units first
      int count = kajalPrices.length;
      int completedBundles = count ~/ 3;
      int freeItemsCount = completedBundles * 2;
      for (int i = 0; i < freeItemsCount && i < kajalPrices.length; i++) {
        discount += kajalPrices[i];
      }
    }

    return discount;
  }

  List<String> get promotionalMessages {
    final List<String> messages = [];

    bool hasHnkTool = false;
    bool hasPaddleBrushInCart = false;
    for (var line in _lines) {
      final numId = _extractNumericId(line['merchandise']?['id']?.toString());
      if (hnkToolVariantIds.contains(numId)) hasHnkTool = true;
      if (numId == hnkPaddleBrushVariantId) hasPaddleBrushInCart = true;
    }
    if (hasHnkTool) {
      if (hasPaddleBrushInCart) {
        messages.add("Free Gift Applied: HNK Paddle Hair Brush (₹422.50) is 100% FREE!");
      } else {
        messages.add("Free Gift Qualified: 1x Hnk Paddle Hair Brush (Worth ₹422.50) will be included FREE in your order!");
      }
    }

    int bbQty = 0;
    for (var line in _lines) {
      final numId = _extractNumericId(line['merchandise']?['id']?.toString());
      final qty = (line['quantity'] as int?) ?? 1;
      if (bbCreamVariantIds.contains(numId)) bbQty += qty;
    }
    if (bbQty > 0) {
      int freeCount = (bbQty ~/ 3) * 2;
      if (freeCount > 0) {
        messages.add("Buy 1 Get 2 Free Applied! ($freeCount Gorgeous Girl BB Cream${freeCount > 1 ? 's are' : ' is'} 100% FREE)");
      } else if (bbQty == 2) {
        messages.add("Buy 1 Get 2 Free: Add 1 more BB Cream to get 2 items 100% FREE in your cart!");
      } else if (bbQty == 1) {
        messages.add("Buy 1 Get 2 Free: Add 2 more BB Creams to get 2 items 100% FREE in your cart!");
      }
    }

    int kajalQty = 0;
    for (var line in _lines) {
      final numId = _extractNumericId(line['merchandise']?['id']?.toString());
      final qty = (line['quantity'] as int?) ?? 1;
      if (kajalVariantIds.contains(numId)) kajalQty += qty;
    }
    if (kajalQty > 0) {
      int freeCount = (kajalQty ~/ 3) * 2;
      if (freeCount > 0) {
        messages.add("Buy 1 Get 2 Free Applied! ($freeCount Gorgeous Girl Kajal${freeCount > 1 ? 's are' : ' is'} 100% FREE)");
      } else if (kajalQty == 2) {
        messages.add("Buy 1 Get 2 Free: Add 1 more Kajal to get 2 items 100% FREE in your cart!");
      } else if (kajalQty == 1) {
        messages.add("Buy 1 Get 2 Free: Add 2 more Kajals to get 2 items 100% FREE in your cart!");
      }
    }

    return messages;
  }

  /// ---------------- DISCOUNT CODES ----------------
  
  String? _appliedCoupon;
  double _couponDiscount = 0;
  
  String? get cartId => _cartId;
  String? get appliedCoupon => _appliedCoupon;
  double get couponDiscount => _couponDiscount;

  double _sumDiscountAllocations(List? allocations) {
    if (allocations == null) return 0;
    double sum = 0;
    for (final allocation in allocations) {
      final amount = allocation['discountedAmount']?['amount'];
      sum += double.tryParse(amount?.toString() ?? '0') ?? 0;
    }
    return sum;
  }

  void _syncCouponStateFromCart(Map<String, dynamic> cart) {
    final discountCodes = cart['discountCodes'] as List? ?? [];
    final applicableCodes = discountCodes
        .where((entry) => entry['applicable'] == true)
        .toList();

    if (applicableCodes.isEmpty) {
      _appliedCoupon = null;
      _couponDiscount = 0;
      return;
    }

    _appliedCoupon = applicableCodes.first['code']?.toString();

    // subtotalAmount is BEFORE cart-level discount codes; use allocations/totalAmount.
    double discount = _sumDiscountAllocations(
      cart['discountAllocations'] as List?,
    );

    if (discount <= 0) {
      final totalRaw = cart['cost']?['totalAmount']?['amount'];
      final double cartTotal =
          double.tryParse(totalRaw?.toString() ?? '0') ?? totalSellingPrice;
      discount = totalSellingPrice - cartTotal;
    }

    _couponDiscount = discount > 0 ? discount : 0;
  }

  String? _messageFromDiscountWarnings(List? warnings) {
    if (warnings == null || warnings.isEmpty) return null;

    final code = warnings.first['code']?.toString() ?? '';
    final message = warnings.first['message']?.toString();

    switch (code) {
      case 'DISCOUNT_CURRENTLY_INACTIVE':
        return "This coupon is not active for the mobile app. In Shopify Admin, edit the discount and enable it for your Headless / custom app sales channel (not only Online Store).";
      case 'DISCOUNT_CUSTOMER_USAGE_LIMIT_REACHED':
      case 'DISCOUNT_USAGE_LIMIT_REACHED':
        return "You have already used this coupon.";
      case 'DISCOUNT_CUSTOMER_NOT_ELIGIBLE':
      case 'DISCOUNT_ELIGIBLE_CUSTOMER_MISSING':
        return "This coupon is not available for your account.";
      case 'DISCOUNT_NO_ENTITLED_LINE_ITEMS':
        return "This coupon does not apply to the items in your cart.";
      case 'DISCOUNT_NOT_FOUND':
        return "Invalid coupon code.";
      case 'DISCOUNT_CODE_NOT_HONOURED':
        return message ?? "This coupon cannot be applied to your cart.";
      default:
        return message;
    }
  }

  Future<String?> applyDiscountCode(String code) async {
    if (_cartId == null) return "Cart is empty";

    final normalizedCode = code.trim().toUpperCase();
    if (normalizedCode.isEmpty) return "Enter a coupon code";

    _isLoading = true;
    notifyListeners();

    final client = getShopifyClient();

    const mutation = r'''
      mutation cartDiscountCodesUpdate($cartId: ID!, $discountCodes: [String!]) {
        cartDiscountCodesUpdate(cartId: $cartId, discountCodes: $discountCodes) {
          cart {
            discountCodes {
              code
              applicable
            }
            discountAllocations {
              discountedAmount { amount }
              ... on CartCodeDiscountAllocation {
                code
              }
            }
            cost {
              subtotalAmount { amount }
              totalAmount { amount }
            }
          }
          userErrors {
            message
          }
          warnings {
            code
            message
          }
        }
      }
    ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "cartId": _cartId,
          "discountCodes": [normalizedCode],
        },
      ),
    );

    _isLoading = false;

    if (result.hasException) {
      notifyListeners();
      return "Network error";
    }

    final payload = result.data?['cartDiscountCodesUpdate'];
    final userErrors = payload?['userErrors'];
    if (userErrors != null && userErrors.isNotEmpty) {
      notifyListeners();
      return userErrors[0]['message'];
    }

    final cart = payload?['cart'];
    if (cart == null) {
      notifyListeners();
      return "Failed to apply coupon";
    }

    final discountCodes = cart['discountCodes'] as List? ?? [];

    if (discountCodes.isEmpty) {
      notifyListeners();
      return "Invalid coupon code";
    }

    final appliedCode = discountCodes.firstWhere(
      (entry) =>
          (entry['code']?.toString().toUpperCase() ?? '') == normalizedCode,
      orElse: () => discountCodes.first,
    );

    if (appliedCode['applicable'] != true) {
      await removeDiscountCode();
      notifyListeners();
      return _messageFromDiscountWarnings(payload?['warnings'] as List?) ??
          "Coupon is not applicable to your cart";
    }

    _syncCouponStateFromCart(cart);

    notifyListeners();
    return null;
  }

  Future<void> removeDiscountCode() async {
    if (_cartId == null) return;
    
    _isLoading = true;
    notifyListeners();

    final client = getShopifyClient();

    const mutation = r'''
      mutation cartDiscountCodesUpdate($cartId: ID!) {
        cartDiscountCodesUpdate(cartId: $cartId, discountCodes: []) {
          cart {
            id
          }
        }
      }
    ''';

    await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "cartId": _cartId,
        },
      ),
    );

    _appliedCoupon = null;
    _couponDiscount = 0;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateBuyerIdentity(String customerAccessToken) async {
    if (_cartId == null) return;

    final client = getShopifyClient();
    const mutation = r'''
      mutation cartBuyerIdentityUpdate($cartId: ID!, $buyerIdentity: CartBuyerIdentityInput!) {
        cartBuyerIdentityUpdate(cartId: $cartId, buyerIdentity: $buyerIdentity) {
          cart {
            id
            discountCodes {
              code
              applicable
            }
            discountAllocations {
              discountedAmount { amount }
              ... on CartCodeDiscountAllocation {
                code
              }
            }
            cost {
              totalAmount { amount }
            }
          }
        }
      }
    ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {
          "cartId": _cartId,
          "buyerIdentity": {
            "customerAccessToken": customerAccessToken,
          }
        },
      ),
    );

    final cart = result.data?['cartBuyerIdentityUpdate']?['cart'];
    if (cart != null) {
      _syncCouponStateFromCart(cart);
      notifyListeners();
    }
  }

  void resetCartState() {
    _cartId = null;
    _checkoutUrl = null;
    _lines = [];
    _appliedCoupon = null;
    _couponDiscount = 0;
    _isLoading = false;
    _clearCartStorage();
    notifyListeners();
  }
}

