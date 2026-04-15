import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shimmer/shimmer.dart';

import '../queries/brands_query.dart';
import '../models/collection.dart';
import '../screens/collection_products_screen.dart';
class BrandCollectionSection extends StatelessWidget {
  const BrandCollectionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Shop By Brands",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Query(
            options: QueryOptions(
              document: gql(collectionsQuery),
            ),
            builder: (result, {fetchMore, refetch}) {

              if (result.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (result.hasException) {

                return const Center(
                  child: Text("Failed to load brands"),
                );
              }

              final edges =
              result.data!['collections']['edges'] as List;

              final allCollections = edges
                  .map((e) => CollectionModel.fromJson(e['node']))
                  .toList();


              final brands = allCollections
                  .where((c) =>
              c.showInMobile &&
                  (c.collectiontype ?? '').toLowerCase().trim() == 'brand')
                  .toList();

              if (brands.isEmpty) {
                return const Center(
                  child: Text("No brands available"),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: brands.length,
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                    childAspectRatio: 1.0
                ),
                itemBuilder: (context, index) {
                  final brand = brands[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CollectionProductsScreen(
                            collectionId: brand.handle,
                            collectionTitle: brand.mobileTitle ?? brand.title,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SizedBox(
                            height: constraints.maxWidth, // ✅ PERFECT SQUARE
                            child: Image.network(
                              brand.mobileBanner ?? brand.image,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}


class BrandShimmerCard extends StatelessWidget {
  const BrandShimmerCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          color: Colors.white,
        ),
      ),
    );
  }
}