class CartItem {
  final String id;
  final String productTitle;
  final String variantTitle;
  final double price;
  final double? compareAt;
  final String image;
  int quantity;

  CartItem({
    required this.id,
    required this.productTitle,
    required this.variantTitle,
    required this.price,
    required this.image,
    this.compareAt,
    this.quantity = 1,
  });

  bool get hasDiscount =>
      compareAt != null && compareAt! > price;

  int get discountPercent =>
      hasDiscount
          ? (((compareAt! - price) / compareAt!) * 100).round()
          : 0;
}