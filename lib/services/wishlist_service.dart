import 'package:graphql_flutter/graphql_flutter.dart';
import '../config/shopify_client.dart';
import '../models/product.dart';

class WishlistService {
  static Future<Product?> fetchProductById(String id) async {
    final client = getShopifyClient();

    final result = await client.query(
      QueryOptions(
        document: gql(_productByIdQuery),
        variables: {"id": id},
      ),
    );

    if (result.hasException || result.data == null) {
      return null;
    }

    final productData = result.data!['product'];

    if (productData == null) return null;

    return Product.fromJson(productData);
  }
}

const String _productByIdQuery = r'''
query GetProductById($id: ID!) {
  product(id: $id) {
    id
    title
    images(first: 1) {
      edges {
        node { url }
      }
    }
    variants(first: 1) {
      edges {
        node {
          id
          price { amount }
          compareAtPrice { amount }
        }
      }
    }
  }
}
''';