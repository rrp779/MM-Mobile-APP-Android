import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../config/shopify_client.dart';
import '../queries/products_query.dart';
import '../models/product.dart';

class ProductListScreen extends StatelessWidget {
  const ProductListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GraphQLProvider(
      client: ValueNotifier(getShopifyClient()),
      child: Scaffold(
        appBar: AppBar(title: const Text("Shopify Products")),
        body: Query(
          options: QueryOptions(document: gql(productsQuery)),
          builder: (result, {fetchMore, refetch}) {
            if (result.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (result.hasException) {
              return Center(
                child: Text(result.exception.toString()),
              );
            }

            final items =
            result.data!['productListings']['edges'] as List;

            final products =
            items.map((e) => Product.fromJson(e['node'])).toList();

            return ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: product.image.isNotEmpty
                        ? Image.network(
                      product.image,
                      width: 60,
                      fit: BoxFit.cover,
                    )
                        : const Icon(Icons.image_not_supported),
                    title: Text(product.title),
                    subtitle:
                    Text("\$${product.price.toStringAsFixed(2)}"),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
