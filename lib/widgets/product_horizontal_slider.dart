import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../models/product.dart';
import '../models/product_variant.dart';
import '../widgets/product_card.dart';
import '../graphql/related_products_query.dart';
import '../graphql/related_collection_products_query.dart';

class ProductHorizontalSlider extends StatelessWidget {
  final String productId;
  final String title;
  final bool useCollectionLogic;

  const ProductHorizontalSlider({
    super.key,
    required this.productId,
    required this.title,
    this.useCollectionLogic = false,
  });

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(
          useCollectionLogic
              ? relatedCollectionProductsQuery
              : relatedProductsQuery,
        ),
        variables: {
          "productId": productId,
        },
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (result.hasException || result.data == null) {

          return const SizedBox();
        }

        List<Product> products = [];

        /// ===============================
        /// 🔹 MORE LIKE THIS (AI)
        /// ===============================
        if (!useCollectionLogic) {
          final List data =
              result.data?['productRecommendations'] ?? [];

          products = data
              .map((e) => Product.fromJson(e))
              .where((p) => p.id != productId)
              .take(10)
              .toList();
        }

        /// ===============================
        /// 🔹 RELATED (Same Collections)
        /// ===============================
        else {
          final collections =
              result.data?['product']?['collections']?['edges'] ?? [];

          print("Collections found: ${collections.length}");

          for (var collection in collections) {
            final productEdges =
                collection['node']?['products']?['edges'] ?? [];

            print("Products inside collection: ${productEdges.length}");

            for (var p in productEdges) {
              final node = p['node'];
              if (node == null) continue;

              if (node['id'] == productId) continue;

              final imageEdges = node['images']?['edges'] ?? [];
              final variantEdges = node['variants']?['edges'] ?? [];

              if (variantEdges.isEmpty) {
                print("Skipping product without variants");
                continue;
              }

              final variants = variantEdges
                  .map((e) => ProductVariant.fromJson(e['node']))
                  .toList();

              final imagesList = imageEdges
                  .map((e) => e['node']?['url']?.toString() ?? '')
                  .where((url) => url.isNotEmpty)
                  .toList();

              try {
                products.add(
                  Product(
                    id: node['id']?.toString() ?? '',
                    title: node['title']?.toString() ?? '',
                    image:
                    imagesList.isNotEmpty ? imagesList.first : '',
                    images: imagesList,
                    descriptionHtml:
                    node['descriptionHtml']?.toString() ?? '',
                    variants: variants,
                  ),
                );

               // print("Added related product: ${node['title']}");
              } catch (e) {
               // print("Error building related product: $e");
              }
            }
          }

          /// Remove duplicates
          products = {
            for (var p in products) p.id: p
          }.values.toList();

          /// Limit to 10
          products = products.take(10).toList();

         // print("Final related products count: ${products.length}");
        }

        if (products.isEmpty) {
         // print("Slider empty for: $title");
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 340,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 190,
                    child: Padding(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 0),
                      child: ProductCard(
                        product: products[index],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}