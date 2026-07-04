import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_icon.dart';
import '../models/product.dart';
import '../providers/wishlist_provider.dart';
import '../utils/animated_toast.dart';
import '../utils/animated_cart_toast.dart';
import '../screens/product_detail_screen.dart';
import '../providers/cart_provider.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final String? collectionTitle;

  const ProductCard({
    super.key,
    required this.product,
    this.collectionTitle,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool isLoading = false;

  String formatPrice(double amount) {
    return "₹ ${amount.toStringAsFixed(2)}";
  }

  Widget _buildVariantCounts(Product product) {
    if (product.variants.isEmpty) return const SizedBox();

    final Set<String> shades = {};
    final Set<String> sizes = {};

    for (var variant in product.variants) {
      for (var option in variant.selectedOptions) {
        final name = option["name"]?.toLowerCase() ?? "";
        final value = option["value"]?.toLowerCase() ?? "";

        if (name.contains("color") || name.contains("shade")) {
          shades.add(value);
        }

        if (name.contains("size") ||
            value.contains("ml") ||
            value.contains("g") ||
            value.contains("kg") ||
            value.contains("pack")) {
          sizes.add(value);
        }
      }
    }

    if (shades.length <= 1 && sizes.length <= 1) {
      return const SizedBox(height: 18);
    }

    return SizedBox(
      height: 18,
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          children: [
            if (shades.length > 1) ...[
              Image.asset('assets/icons/VariantShades.png', width: 14),
              const SizedBox(width: 4),
              Text("${shades.length} Shades",
                  style: const TextStyle(fontSize: 11)),
            ],
            if (sizes.length > 1) ...[
              const SizedBox(width: 10),
              Image.asset('assets/icons/VariantSize.png', width: 14),
              const SizedBox(width: 4),
              Text("${sizes.length} Sizes",
                  style: const TextStyle(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final wishlistProvider = context.watch<WishlistProvider>();

    final isOutOfStock =
        product.variants.isNotEmpty &&
            product.variants.every((v) => v.isOutOfStock);

    final hasDiscount =
        product.compareAt != null &&
            product.compareAt! > product.price;

    final discountPercent = hasDiscount
        ? (((product.compareAt! - product.price) /
        product.compareAt!) *
        100)
        .round()
        : 0;

    final isWishlisted =
    wishlistProvider.isInWishlist(product.id);

    final isSingleVariant = product.variantCount == 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 170.0;
        final cardHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 330.0;
        final imageHeight = (cardHeight * 0.46).clamp(120.0, cardWidth);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

          /// IMAGE
              GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailScreen(productId: product.id),
                ),
              );
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: imageHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Color(0xFFE1E1E1),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              product.image,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                if (isOutOfStock)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        "OUT OF STOCK",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () {
                      final isAlready =
                      wishlistProvider.isInWishlist(product.id);

                      wishlistProvider.toggle(product.id);

                      showAnimatedWishlistToast(
                        context,
                        added: !isAlready,
                      );
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: AppIcon(
                        isActive: isWishlisted,
                        outlinePath: 'assets/icons/HeartOutline.svg',
                        filledPath: 'assets/icons/HeartBold.svg',
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

              /// BRAND
              if (product.brandTitle != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    product.brandTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFEA0180),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

          /// TITLE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SizedBox(
                  height: 32,
                  child: Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, height: 1.2),
                  ),
                ),
              ),

          /// VARIANTS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildVariantCounts(product),
              ),

          /// PRICE
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          if (hasDiscount) ...[
                            Text(
                              formatPrice(product.compareAt!),
                              style: const TextStyle(
                                fontSize: 12,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            formatPrice(product.price),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        "($discountPercent% OFF)",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 1),

          /// BUTTON WITH LOADER
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA0180),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                onPressed: (isOutOfStock || isLoading)
                    ? null
                    : () async {
                  setState(() => isLoading = true);

                  try {
                    if (isSingleVariant) {
                      final cartProvider =
                      context.read<CartProvider>();
                      final variantId =
                          product.variants.first.id;

                      final alreadyInCart =
                      cartProvider.containsVariant(variantId);

                      await cartProvider.addToCart(
                        variantId: variantId,
                        quantity: 1,
                      );

                      showAnimatedCartToast(
                        context,
                        added: !alreadyInCart,
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailScreen(
                                  productId: product.id),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() => isLoading = false);
                    }
                  }
                },
                child: isLoading
                    ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  isOutOfStock
                      ? "OUT OF STOCK"
                      : (isSingleVariant
                      ? "Add to Cart"
                      : "Quick View"),
                  style: TextStyle(
                    fontSize: 12,
                    color: isOutOfStock
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
                  ),
                ),
              ),

              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
