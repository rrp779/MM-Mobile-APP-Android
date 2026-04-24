import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/shopify_client.dart';

class CartProvider with ChangeNotifier {
  String? _cartId;
  String? _checkoutUrl;
  Map<String, dynamic>? _cost;
  List<Map<String, dynamic>> _discountAllocations = [];

  List<Map<String, dynamic>> _lines = [];

  bool _isLoading = false;

  String? get checkoutUrl => _checkoutUrl;
  Map<String, dynamic>? get cost => _cost;
  List<Map<String, dynamic>> get discountAllocations => _discountAllocations;
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
    return _parseAmount(_cost?['totalAmount']?['amount']);
  }

  double get cartDiscountTotal {
    return _discountAllocations.fold(0.0, (double sum, allocation) {
      return sum + _parseAmount(allocation['discountedAmount']?['amount']);
    });
  }

  double get productPriceDiscount {
    return totalMrp - totalAmount;
  }

  double get totalDiscount {
    return productPriceDiscount + cartDiscountTotal;
  }

  bool containsVariant(String variantId) {
    return _lines.any(
      (line) => line['merchandise']['id'] == variantId,
    );
  }

  CartProvider() {
    _initializeCart();
  }

  Future<void> _initializeCart() async {
    await _loadStoredCartId();
    if (_cartId != null) {
      await _ensureCartBuyerIdentity();
      await _fetchCartFromId();
    }
  }

  Future<void> _loadStoredCartId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cartId = prefs.getString('shopify_cart_id');
    } catch (e) {
      debugPrint('Failed to load stored cart ID: $e');
    }
  }

  Future<void> _saveCartId(String cartId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('shopify_cart_id', cartId);
    } catch (e) {
      debugPrint('Failed to save cart ID: $e');
    }
  }

  Future<void> _clearStoredCartId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('shopify_cart_id');
    } catch (e) {
      debugPrint('Failed to clear cart ID: $e');
    }
  }

  Future<void> _fetchCartFromId() async {
    if (_cartId == null) return;

    final client = getShopifyClient();
    const query = r'''
      query GetCart($cartId: ID!) {
        cart(id: $cartId) {
          id
          checkoutUrl
          cost {
            subtotalAmount { amount }
            totalAmount { amount }
          }
          discountAllocations {
            discountedAmount { amount }
          }
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
                    product { title }
                    price { amount }
                    compareAtPrice { amount }
                  }
                }
                discountAllocations {
                  discountedAmount { amount }
                }
              }
            }
          }
        }
      }
    ''';

    final result = await client.query(
      QueryOptions(
        document: gql(query),
        variables: {'cartId': _cartId},
        fetchPolicy: FetchPolicy.networkOnly,
      ),
    );

    if (result.hasException) {
      debugPrint('Cart fetch failed: ${result.exception}');
      _cartId = null;
      _checkoutUrl = null;
      await _clearStoredCartId();
      notifyListeners();
      return;
    }

    final cart = result.data?['cart'];
    if (cart == null) {
      _cartId = null;
      _checkoutUrl = null;
      await _clearStoredCartId();
      notifyListeners();
      return;
    }

    _updateCartFromResponse(cart as Map<String, dynamic>);
  }

  Future<void> _createCart() async {
    final client = getShopifyClient();

    const mutation = r'''
    mutation {
      cartCreate(input: { buyerIdentity: { countryCode: IN } }) {
        cart {
          id
          checkoutUrl
          cost {
            subtotalAmount { amount }
            totalAmount { amount }
          }
          discountAllocations {
            discountedAmount { amount }
          }
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
                    product { title }
                    price { amount }
                    compareAtPrice { amount }
                  }
                }
                discountAllocations {
                  discountedAmount { amount }
                }
              }
            }
          }
        }
      }
    }
    ''';

    final result = await client.mutate(
      MutationOptions(document: gql(mutation)),
    );

    debugPrint('CartCreate response: ${result.data}');

    if (result.hasException) {
      debugPrint(result.exception.toString());
      return;
    }

    final cart = result.data?['cartCreate']?['cart'] as Map<String, dynamic>?;
    if (cart == null) return;

    _cartId = cart['id'];
    _checkoutUrl = cart['checkoutUrl'];
    await _saveCartId(_cartId!);

    notifyListeners();
  }

  Future<void> _ensureCartBuyerIdentity() async {
    if (_cartId == null) return;

    final client = getShopifyClient();
    const mutation = r'''
      mutation UpdateBuyerIdentity($cartId: ID!) {
        cartBuyerIdentityUpdate(
          cartId: $cartId
          buyerIdentity: { countryCode: IN }
        ) {
          cart {
            id
            checkoutUrl
            cost {
              subtotalAmount { amount }
              totalAmount { amount }
            }
            discountAllocations {
              discountedAmount { amount }
            }
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
                      product { title }
                      price { amount }
                      compareAtPrice { amount }
                    }
                  }
                  discountAllocations {
                    discountedAmount { amount }
                  }
                }
              }
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    ''';

    final result = await client.mutate(
      MutationOptions(
        document: gql(mutation),
        variables: {'cartId': _cartId},
      ),
    );

    if (result.hasException) {
      debugPrint('Buyer identity update failed: ${result.exception}');
      return;
    }

    final userErrors = result.data?['cartBuyerIdentityUpdate']?['userErrors'];
    if (userErrors is List && userErrors.isNotEmpty) {
      debugPrint('Buyer identity userErrors: $userErrors');
    }

    final cart = result.data?['cartBuyerIdentityUpdate']?['cart']
        as Map<String, dynamic>?;
    if (cart != null) {
      _updateCartFromResponse(cart);
    }
  }

  Future<void> addToCart({
    required String variantId,
    int quantity = 1,
  }) async {
    if (_cartId == null) {
      await _createCart();
    }

    if (_cartId == null) return;

    await _ensureCartBuyerIdentity();

    _isLoading = true;
    notifyListeners();

    final existingLine = _lines
        .where((line) => line['merchandise']['id'] == variantId)
        .toList();

    if (existingLine.isNotEmpty) {
      await updateQuantity(
        lineId: existingLine.first['id'],
        quantity: existingLine.first['quantity'] + quantity,
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    final client = getShopifyClient();

    const mutation = r'''
    mutation AddToCart($cartId: ID!, $lines: [CartLineInput!]!) {
      cartLinesAdd(cartId: $cartId, lines: $lines) {
        cart {
          id
          checkoutUrl
          cost {
            subtotalAmount { amount }
            totalAmount { amount }
          }
          discountAllocations {
            discountedAmount { amount }
          }
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
                    product { title }
                    price { amount }
                    compareAtPrice { amount }
                  }
                }
                discountAllocations {
                  discountedAmount { amount }
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
          "lines": [
            {
              "merchandiseId": variantId,
              "quantity": quantity,
            }
          ],
        },
      ),
    );

    debugPrint('CartLinesAdd response: ${result.data}');

    if (result.hasException) {
      debugPrint(result.exception.toString());
      _isLoading = false;
      notifyListeners();
      return;
    }

    final cart =
        result.data?['cartLinesAdd']?['cart'] as Map<String, dynamic>?;
    if (cart == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _updateCartFromResponse(cart);
  }

  Future<void> updateQuantity({
    required String lineId,
    required int quantity,
  }) async {
    if (_cartId == null) return;

    await _ensureCartBuyerIdentity();

    _isLoading = true;
    notifyListeners();

    final client = getShopifyClient();

    const mutation = r'''
    mutation UpdateCart($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
      cartLinesUpdate(cartId: $cartId, lines: $lines) {
        cart {
          id
          checkoutUrl
          cost {
            subtotalAmount { amount }
            totalAmount { amount }
          }
          discountAllocations {
            discountedAmount { amount }
          }
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
                    product { title }
                    price { amount }
                    compareAtPrice { amount }
                  }
                }
                discountAllocations {
                  discountedAmount { amount }
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
          "lines": [
            {
              "id": lineId,
              "quantity": quantity,
            }
          ],
        },
      ),
    );

    debugPrint('CartLinesUpdate response: ${result.data}');

    if (result.hasException) {
      debugPrint(result.exception.toString());
      _isLoading = false;
      notifyListeners();
      return;
    }

    final cart =
        result.data?['cartLinesUpdate']?['cart'] as Map<String, dynamic>?;
    if (cart == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _updateCartFromResponse(cart);
  }

  Future<void> removeItem(String lineId) async {
    if (_cartId == null) return;

    await _ensureCartBuyerIdentity();

    _isLoading = true;
    notifyListeners();

    final client = getShopifyClient();

    const mutation = r'''
    mutation RemoveItem($cartId: ID!, $lineIds: [ID!]!) {
      cartLinesRemove(cartId: $cartId, lineIds: $lineIds) {
        cart {
          id
          checkoutUrl
          cost {
            subtotalAmount { amount }
            totalAmount { amount }
          }
          discountAllocations {
            discountedAmount { amount }
          }
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
                    product { title }
                    price { amount }
                    compareAtPrice { amount }
                  }
                }
                discountAllocations {
                  discountedAmount { amount }
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

    debugPrint('CartLinesRemove response: ${result.data}');

    if (result.hasException) {
      debugPrint(result.exception.toString());
      _isLoading = false;
      notifyListeners();
      return;
    }

    final cart =
        result.data?['cartLinesRemove']?['cart'] as Map<String, dynamic>?;
    if (cart == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _updateCartFromResponse(cart);
  }

  Future<void> clearCart() async {
    final ids = _lines.map((e) => e['id']).toList();
    for (var id in ids) {
      await removeItem(id);
    }
  }

  void _updateCartFromResponse(Map<String, dynamic> cart) {
    _checkoutUrl = cart['checkoutUrl'];
    _cost = cart['cost'] as Map<String, dynamic>?;
    _discountAllocations = (cart['discountAllocations'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList() ??
        [];

    _lines = (cart['lines']['edges'] as List)
        .map((e) => e['node'] as Map<String, dynamic>)
        .toList();

    _logCartSnapshot(
      tag: 'cart_update',
      cartId: cart['id']?.toString(),
      rawCart: cart,
    );

    _isLoading = false;
    notifyListeners();
  }

  double get totalMrp {
    return _parseAmount(_cost?['subtotalAmount']?['amount']);
  }

  double get totalSellingPrice {
    return _parseAmount(_cost?['totalAmount']?['amount']);
  }

  double _parseAmount(dynamic raw) {
    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw) ?? 0;
    return 0;
  }

  void _logCartSnapshot({
    required String tag,
    String? cartId,
    Map<String, dynamic>? rawCart,
  }) {
    final subtotal = _parseAmount(_cost?['subtotalAmount']?['amount']);
    final total = _parseAmount(_cost?['totalAmount']?['amount']);
    final cartLevelDiscount = _discountAllocations.fold<double>(
      0,
      (sum, allocation) =>
          sum + _parseAmount(allocation['discountedAmount']?['amount']),
    );

    double lineLevelDiscount = 0;
    for (final line in _lines) {
      final allocations = (line['discountAllocations'] as List?) ?? [];
      for (final a in allocations) {
        lineLevelDiscount += _parseAmount(
          (a as Map<String, dynamic>)['discountedAmount']?['amount'],
        );
      }
    }

    debugPrint('========== SHOPIFY CART DEBUG [$tag] ==========');
    debugPrint('cartId: ${cartId ?? _cartId}');
    debugPrint('checkoutUrl: $_checkoutUrl');
    debugPrint('subtotalAmount: $subtotal');
    debugPrint('totalAmount: $total');
    debugPrint('discountByCost(subtotal-total): ${(subtotal - total).toStringAsFixed(2)}');
    debugPrint('cartLevelDiscountAllocations: $cartLevelDiscount');
    debugPrint('lineLevelDiscountAllocations: $lineLevelDiscount');
    debugPrint('lineCount: ${_lines.length}');

    for (final line in _lines) {
      final merchandise = (line['merchandise'] as Map<String, dynamic>? ?? {});
      final product = (merchandise['product'] as Map<String, dynamic>? ?? {});
      final title = product['title']?.toString() ?? 'Unknown';
      final qty = (line['quantity'] as int?) ?? 0;
      final price = _parseAmount(merchandise['price']?['amount']);
      final compareAt = _parseAmount(merchandise['compareAtPrice']?['amount']);

      double lineDisc = 0;
      final allocations = (line['discountAllocations'] as List?) ?? [];
      for (final a in allocations) {
        lineDisc += _parseAmount(
          (a as Map<String, dynamic>)['discountedAmount']?['amount'],
        );
      }

      debugPrint(
        'line: "$title" qty=$qty price=$price compareAt=$compareAt lineDiscount=$lineDisc',
      );
    }

    if (rawCart != null) {
      debugPrint('rawCost: ${rawCart['cost']}');
      debugPrint('rawDiscountAllocations: ${rawCart['discountAllocations']}');
    }
    debugPrint('==============================================');
  }
}