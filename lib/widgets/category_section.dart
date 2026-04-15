import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/collection.dart';
import '../screens/collection_products_screen.dart';

class CategorySection extends StatelessWidget {
  final String title;
  final List<CollectionModel> categories;

  const CategorySection({
    super.key,
    required this.title,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox();

    final bannerImage =
        categories.first.mobileBanner ?? categories.first.image;

    /// 🔥 Responsive column count
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = width ~/ 120;
    if (crossAxisCount < 2) crossAxisCount = 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// 🔥 Banner (CACHED)
        Container(
          height: 200,
          width: double.infinity,
          margin: const EdgeInsets.only(top: 16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _cachedImage(
                bannerImage,
                fit: BoxFit.cover,
              ),
              Container(color: Colors.black.withOpacity(0.3)),
              Positioned(
                right: 20,
                bottom: 20,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        /// 🔥 Subcategory Grid (RESPONSIVE FIXED)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            cacheExtent: 200,
            itemCount: categories.length,
            gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              final category = categories[index];

              final image =
                  category.mobileBanner ?? category.image;

              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CollectionProductsScreen(
                        collectionId: category.handle,
                        collectionTitle: category.title,
                        isBrand: false,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _cachedImage(
                    image,
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),

      ],
    );
  }

  /// 🔥 REUSABLE CACHED IMAGE
  Widget _cachedImage(
      String? url, {
        BoxFit fit = BoxFit.cover,
      }) {
    if (url == null || url.isEmpty) {
      return Container(color: Colors.grey[200]);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      memCacheWidth: 400,
      placeholder: (_, __) => Container(color: Colors.grey[200]),
      errorWidget: (_, __, ___) =>
      const Icon(Icons.broken_image, color: Colors.grey),
    );
  }
}