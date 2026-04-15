import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../config/shopify_client.dart';
import '../queries/categories_query.dart';
class CollectionProvider extends ChangeNotifier {

  List<String> categories = [];

  Future<void> fetchCollections() async {

    final client = getShopifyClient();

    final result = await client.query(
      QueryOptions(document: gql(collectionsQuery)),
    );

    if (result.hasException || result.data == null) return;

    final data = result.data!;

    final collections = [
      data['nail-makeup'],
      data['face-makeup'],
      data['eyes'],
    ];

    categories = collections
        .where((e) => e != null)
        .map((e) => e['title'] as String)
        .toList();

    notifyListeners();
  }
}
