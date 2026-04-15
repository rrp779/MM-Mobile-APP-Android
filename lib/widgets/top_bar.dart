import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_icon.dart';
import '../providers/wishlist_provider.dart';
import '../screens/wishlist_screen.dart';
import '../widgets/animated_search_bar.dart';
import '../providers/cart_provider.dart';
import '../screens/cart_page.dart';
import '../providers/notification_provider.dart';
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});
  @override
  Widget build(BuildContext context) {
    final wishlistProvider = context.watch<WishlistProvider>();
    final cartProvider = context.watch<CartProvider>();
   // bool hasNotification = true; // change to false to test
    return Column(
      children: [
        // ───────── TOP ROW ─────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 28,
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/notifications');
                        },
                        icon: AppIcon(
                          isActive: false,
                          outlinePath: 'assets/icons/NotificationOutline.svg',
                          filledPath: 'assets/icons/NotificationBold.svg',
                        ),
                      ),

                      /// 🔴 BADGE COUNT
                      Positioned(
                        right: 6,
                        top: 6,
                        child: Consumer<NotificationProvider>(
                          builder: (context, provider, child) {
                            int count = provider.notifications.length;

                            if (count == 0) return const SizedBox();

                            return Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Text(
                                count > 99 ? '99+' : '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      IconButton(
                        icon: AppIcon(
                          isActive: wishlistProvider
                              .wishlistIds.isNotEmpty,
                          outlinePath:
                          'assets/icons/HeartOutline.svg',
                          filledPath:
                          'assets/icons/HeartOutline.svg',
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const WishlistScreen(),
                            ),
                          );
                        },
                      ),
                      if (wishlistProvider
                          .wishlistIds.isNotEmpty)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            padding:
                            const EdgeInsets.all(4),
                            decoration:
                            const BoxDecoration(
                              color: Color(0xFFEA0180),
                              shape: BoxShape.circle,
                            ),
                            constraints:
                            const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Center(
                              child: Text(
                                wishlistProvider
                                    .wishlistIds.length
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
                    ],
                  ),
                  /// 🛒 CART WITH ANIMATED BADGE
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: AppIcon(
                          isActive: cartProvider.totalQuantity > 0,
                          outlinePath: 'assets/icons/BuyOutline.svg',
                          filledPath: 'assets/icons/BuyOutline.svg',
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CartPage(),
                            ),
                          );
                        },
                      ),

                      if (cartProvider.totalQuantity > 0)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, animation) =>
                                ScaleTransition(scale: animation, child: child),
                            child: Container(
                              key: ValueKey(cartProvider.totalQuantity),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color:const Color(0xFFEA0180),
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              child: Center(
                                child: Text(
                                  cartProvider.totalQuantity.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
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

        // ───────── SEARCH BAR ─────────
        const AnimatedSearchBar(),
        const SizedBox(height: 20),
      ],
    );
  }
}
