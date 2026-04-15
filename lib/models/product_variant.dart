class ProductVariant {
  final String id;
  final String title;
  final double price;
  final double? compareAt;
  final String? image;
  final bool availableForSale;
  final int? quantityAvailable;
  final String? inventoryPolicy;
  final List<Map<String, String>> selectedOptions; // 👈 ADD THIS
  ProductVariant({
    required this.id,
    required this.title,
    required this.price,
    this.compareAt,
    this.image,
    required this.availableForSale,
    this.quantityAvailable,
    this.inventoryPolicy,
    required this.selectedOptions,
  });

  // ✅ ADD THIS HERE 👇
  bool get isOutOfStock {
    // Ignore broken availableForSale when quantity is missing
    if (quantityAvailable == null) {
      return false; // 👈 assume in stock (fixes your Home issue)
    }

    if (inventoryPolicy == "CONTINUE") return false;

    return quantityAvailable! <= 0;
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: handle Shopify "edges -> node"
    final data = json['node'] ?? json;




    final priceValue = data['price'];
    final compareValue = data['compareAtPrice'];

    double price = 0;
    double? compareAt;

    if (priceValue is Map) {
      price = double.tryParse(priceValue['amount']?.toString() ?? '0') ?? 0;
    } else {
      price = double.tryParse(priceValue?.toString() ?? '0') ?? 0;
    }

    if (compareValue != null) {
      if (compareValue is Map) {
        compareAt =
            double.tryParse(compareValue['amount']?.toString() ?? '');
      } else {
        compareAt =
            double.tryParse(compareValue.toString());
      }
    }

    return ProductVariant(
      id: data['id']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      price: price,
      compareAt: compareAt,
      image: data['image']?['url']?.toString(),
      availableForSale: data['availableForSale'] == true,
      quantityAvailable: data['quantityAvailable'],
      inventoryPolicy: data['inventoryPolicy']?.toString(),
      selectedOptions: (data['selectedOptions'] as List?)
          ?.map((e) => {
        "name": e['name'].toString(),
        "value": e['value'].toString(),
      })
          .toList() ??
          [],
    );
  }
}
