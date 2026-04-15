import 'package:graphql_flutter/graphql_flutter.dart';
import '../config/shopify_client.dart';

class ShopifyWishlistService {

  static Future<List<String>> fetchWishlist(
      String accessToken,
      ) async {

    final client = getShopifyClient();

    final result = await client.query(
      QueryOptions(
        document: gql(_getWishlistQuery),
        variables: {"customerAccessToken": accessToken},
      ),
    );

    if (result.hasException || result.data == null) {
      return [];
    }

    final metafield =
    result.data!['customer']['metafield'];

    if (metafield == null) return [];

    return List<String>.from(
      (metafield['value'] as String)
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .split(',')
          .map((e) => e.trim()),
    );
  }

  static Future<void> updateWishlist({
    required String accessToken,
    required List<String> productIds,
  }) async {

    final client = getShopifyClient();

    await client.mutate(
      MutationOptions(
        document: gql(_updateWishlistMutation),
        variables: {
          "customerAccessToken": accessToken,
          "wishlist": productIds.toString(),
        },
      ),
    );
  }
}



const String _getWishlistQuery = r'''
query GetWishlist($customerAccessToken: String!) {
  customer(customerAccessToken: $customerAccessToken) {
    metafield(namespace: "custom", key: "wishlist") {
      value
    }
  }
}
''';

const String _updateWishlistMutation = r'''
mutation UpdateWishlist(
  $customerAccessToken: String!,
  $wishlist: String!
) {
  customerUpdate(
    customerAccessToken: $customerAccessToken,
    customer: {
      metafields: [
        {
          namespace: "custom",
          key: "wishlist",
          value: $wishlist,
          type: "json"
        }
      ]
    }
  ) {
    userErrors {
      message
    }
  }
}
''';