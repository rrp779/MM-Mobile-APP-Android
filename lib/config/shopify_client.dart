import 'package:graphql_flutter/graphql_flutter.dart';
import '../config/shopify_config.dart';

GraphQLClient getShopifyClient() {
  final HttpLink httpLink = HttpLink(
    'https://${ShopifyConfig.storeDomain}/api/2023-10/graphql.json',
    defaultHeaders: {
      'X-Shopify-Storefront-Access-Token':
      ShopifyConfig.storefrontAccessToken,
      'Content-Type': 'application/json', // ✅ add this
    },
  );

  return GraphQLClient(
    cache: GraphQLCache(),
    link: httpLink,
    queryRequestTimeout: const Duration(seconds: 20), // ✅ FIX
  );
}