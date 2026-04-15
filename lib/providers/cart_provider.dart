import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../config/shopify_client.dart';

class CartProvider with ChangeNotifier {
  String? _cartId;
  String? _checkoutUrl;

  List<Map<String, dynamic>> _lines = [];

  bool _isLoading = false;

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

    notifyListeners();
  }

  /// ---------------- ADD TO CART ----------------

  Future<void> addToCart({
    required String variantId,
    int quantity = 1,
  }) async {
    if (_cartId == null) {
      await _createCart();
    }

    if (_cartId == null) return;

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

    if (result.hasException) {
      debugPrint(result.exception.toString());
      _isLoading = false;
      notifyListeners();
      return;
    }

    _updateCartFromResponse(result.data!['cartLinesAdd']['cart']);
  }

  /// ---------------- UPDATE QUANTITY ----------------

  Future<void> updateQuantity({
    required String lineId,
    required int quantity,
  }) async {
    if (_cartId == null) return;

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
                  product { title }
                  price { amount }
                  compareAtPrice { amount }
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
      return;
    }

    _updateCartFromResponse(
        result.data!['cartLinesUpdate']['cart']);
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
                  product { title }
                  price { amount }
                  compareAtPrice { amount }
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
  }

  /// ---------------- HELPER ----------------

  void _updateCartFromResponse(Map<String, dynamic> cart) {
    _checkoutUrl = cart['checkoutUrl'];

    _lines = (cart['lines']['edges'] as List)
        .map((e) => e['node'] as Map<String, dynamic>)
        .toList();

    _isLoading = false;
    notifyListeners();
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
  
}

