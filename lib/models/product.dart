import 'product_variant.dart';

class Product {
  final String id;
  final String title;
  final String image;
  final String descriptionHtml;
  final List<String> images;
  final List<ProductVariant> variants;
  final String? brandTitle;

  Product({
    required this.id,
    required this.title,
    required this.image,
    required this.descriptionHtml,
    required this.images,
    required this.variants,
    this.brandTitle,
  });

  bool get isOutOfStock =>
      variants.every((v) => v.isOutOfStock);

  double get price =>
      variants.isNotEmpty ? variants.first.price : 0;

  double? get compareAt =>
      variants.isNotEmpty ? variants.first.compareAt : null;

  int get variantCount => variants.length;

  int get shadeCount => variants.length;

  int get sizeCount {
    final sizes = variants
        .map((v) => v.title?.toLowerCase())
        .where((t) => t != null && t.contains('ml'))
        .toSet();

    return sizes.length;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final imageEdges = (json['images']?['edges'] ?? []) as List;
    final variantEdges = (json['variants']?['edges'] ?? []) as List;
    final collectionEdges = (json['collections']?['edges'] ?? []) as List;

    final imagesList = imageEdges
        .map((e) => e['node']?['url']?.toString() ?? '')
        .where((url) => url.isNotEmpty)
        .toList();

    String? brandTitle;

    /// Detect brand collection safely
    for (var edge in collectionEdges) {
      final node = edge['node'];

      if (node == null) continue;

      final fields =
      (node['metafield']?['reference']?['fields'] ?? []) as List;

      for (var field in fields) {
        final key =
        field['key']?.toString().toLowerCase();

        final value =
        field['value']?.toString().toLowerCase();

        if ((key == 'type' ||
            key == 'collectiontype' ||
            key == 'collection_type') &&
            value == 'brand') {
          brandTitle = node['title']?.toString();
          break;
        }
      }

      if (brandTitle != null) break;
    }

    /// Variants safe parsing
    List<ProductVariant> variants = [];

    final rawVariants = json['variants'];

    if (rawVariants is Map && rawVariants['edges'] != null) {
      // ✅ Shopify GraphQL format
      variants = (rawVariants['edges'] as List)
          .map((e) => ProductVariant.fromJson(e['node']))
          .toList();
    } else if (rawVariants is List) {
      // ✅ Already parsed / flat list
      variants = rawVariants
          .map((e) => ProductVariant.fromJson(e))
          .toList();
    }



    return Product(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      image: imagesList.isNotEmpty ? imagesList.first : '',
      images: imagesList,
      descriptionHtml: json['descriptionHtml']?.toString() ?? '',
      variants: variants,
      brandTitle: brandTitle,
    );
  }
}