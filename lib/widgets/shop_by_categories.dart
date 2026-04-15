import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../queries/categories_query.dart';
import '../models/collection.dart';
import '../screens/collection_products_screen.dart';class ShopByCategories extends StatelessWidget {
  const ShopByCategories({super.key});

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(collectionsQuery),
      ),
      builder: (result, {refetch, fetchMore}) {

        if (result.isLoading) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (result.hasException) {

          return const SizedBox();
        }

        final edges =
        result.data!['collections']['edges'] as List;

        // 🔥 Parse using CollectionModel (same as brand)
        final categories = edges
            .map((e) => CollectionModel.fromJson(e['node']))
            .where((c) =>
        c.showInMobile &&
            c.collectiontype?.toLowerCase() == 'category')
            .toList();


        if (categories.isEmpty) {
          return const SizedBox();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                "Shop By Categories",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {

                  final category = categories[index];

                  return Container(
                    width: 100,
                    margin:
                    const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CollectionProductsScreen(
                                      collectionId:
                                      category.handle,
                                      collectionTitle:
                                      category.mobileTitle ??
                                          category.title,
                                    ),
                              ),
                            );
                          },
                          child: Container(
                            height: 100,
                            width: 100,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10), // adjust value
                                border: Border.all(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10), // adjust radius here
                              child: Image.network(
                                category.mobileBanner ?? category.image,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.image,
                                    size: 30,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          category.mobileTitle ??
                              category.title,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ],
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
