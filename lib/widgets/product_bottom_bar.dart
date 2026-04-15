import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_icon.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import '../utils/animated_cart_toast.dart';
import '../providers/wishlist_provider.dart';
import '../utils/animated_toast.dart';

class ProductBottomBar extends StatefulWidget {
  final Product product;
  final String selectedVariantId;
  final int quantity;

  const ProductBottomBar({
    super.key,
    required this.product,
    required this.selectedVariantId,
    required this.quantity,
  });

  @override
  State<ProductBottomBar> createState() => _ProductBottomBarState();
}

class _ProductBottomBarState extends State<ProductBottomBar> {
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.read<CartProvider>();

    final selectedVariant = widget.product.variants.firstWhere(
          (v) => v.id == widget.selectedVariantId,
    );

    final isOutOfStock = selectedVariant.isOutOfStock;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: [

            /// ❤️ WISHLIST BUTTON
            Consumer<WishlistProvider>(
              builder: (context, wishlistProvider, _) {
                final isWishlisted =
                wishlistProvider.isInWishlist(widget.product.id);

                return GestureDetector(
                  onTap: () {
                    final already =
                    wishlistProvider.isInWishlist(widget.product.id);

                    wishlistProvider.toggle(widget.product.id);

                    showAnimatedWishlistToast(
                      context,
                      added: !already,
                    );
                  },
                  child: Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: AppIcon(
                          key: ValueKey(isWishlisted),
                          isActive: isWishlisted,
                          outlinePath: 'assets/icons/HeartOutline.svg',
                          filledPath: 'assets/icons/HeartBold.svg',
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(width: 12),

            /// 🛍 ADD TO CART BUTTON
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOutOfStock
                      ? Colors.grey
                      : const Color(0xFFEA0180),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: (isOutOfStock || isLoading)
                    ? null
                    : () async {
                  setState(() => isLoading = true);

                  try {
                    final alreadyInCart =
                    cartProvider.containsVariant(widget.selectedVariantId);

                    await cartProvider.addToCart(
                      variantId: widget.selectedVariantId,
                      quantity: widget.quantity,
                    );

                    showAnimatedCartToast(
                      context,
                      added: !alreadyInCart,
                    );
                  } finally {
                    if (mounted) {
                      setState(() => isLoading = false);
                    }
                  }
                },

                /// 👇 LOADER HERE
                child: isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  isOutOfStock ? "OUT OF STOCK" : "ADD TO CART",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}