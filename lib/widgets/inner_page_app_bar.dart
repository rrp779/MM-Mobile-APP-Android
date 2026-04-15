import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_icon.dart';
import '../providers/wishlist_provider.dart';
import '../screens/wishlist_screen.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_page.dart';

class InnerPageAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String? productId;
  final String title;

  const InnerPageAppBar({
    super.key,
    required this.title,
    this.productId,
  });

  /// 👇 REQUIRED for Scaffold.appBar
  @override
  Size get preferredSize => const Size.fromHeight(120);

  @override
  Widget build(BuildContext context) {
    final wishlistProvider = Provider.of<WishlistProvider>(context, listen: true);
    final cartProvider = context.watch<CartProvider>();

    return Material(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // ───────── TOP ROW ─────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  /// 🔙 BACK ARROW + TITLE
                  Row(
                    children: [
                      IconButton(
                        icon: AppIcon(
                          isActive: false,
                          outlinePath: 'assets/icons/ArrowLeft.svg',
                          filledPath: 'assets/icons/ArrowLeft.svg',
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(width: 4),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  /// RIGHT SIDE ICONS
                  Row(
                    children: [

                      /// 🔔 Notification
                      IconButton(
                        onPressed: () {},
                        icon: AppIcon(
                          isActive: false,
                          outlinePath:
                          'assets/icons/NotificationOutline.svg',
                          filledPath:
                          'assets/icons/NotificationBold.svg',
                        ),
                      ),

                      /// ❤️ Wishlist
                      Stack(
                        children: [
                          IconButton(
                            icon: AppIcon(
                              isActive: productId != null
                                  ? wishlistProvider.isInWishlist(productId!)
                                  : wishlistProvider.wishlistIds.isNotEmpty,
                              outlinePath: 'assets/icons/HeartOutline.svg',
                              filledPath: 'assets/icons/HeartOutline.svg',
                            ),
                            onPressed: () {
                              if (productId != null) {
                                context.read<WishlistProvider>().toggle(productId!);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const WishlistScreen(),
                                  ),
                                );
                              }
                            },
                          ),

                          /// 🔴 Badge (only show when NOT on product page)
                          if (productId == null &&
                              wishlistProvider.wishlistIds.isNotEmpty)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEA0180),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Center(
                                  child: Text(
                                    wishlistProvider.wishlistIds.length.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),

                      /// 🛒 Cart
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          IconButton(
                            icon: AppIcon(
                              isActive:
                              cartProvider.totalQuantity > 0,
                              outlinePath:
                              'assets/icons/BuyOutline.svg',
                              filledPath:
                              'assets/icons/BuyOutline.svg',
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                  const CartPage(),
                                ),
                              );
                            },
                          ),
                          if (cartProvider.totalQuantity > 0)
                            Positioned(
                              right: 6,
                              top: 6,
                              child: AnimatedSwitcher(
                                duration: const Duration(
                                    milliseconds: 300),
                                transitionBuilder:
                                    (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                child: Container(
                                  key: ValueKey(
                                      cartProvider
                                          .totalQuantity),
                                  padding:
                                  const EdgeInsets.all(
                                      4),
                                  decoration:
                                  const BoxDecoration(
                                    color:
                                    Color(0xFFEA0180),
                                    shape:
                                    BoxShape.circle,
                                  ),
                                  constraints:
                                  const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Center(
                                    child: Text(
                                      cartProvider
                                          .totalQuantity
                                          .toString(),
                                      style:
                                      const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight:
                                        FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

          ],
        ),
      ),
    );
  }
}