import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/app_icon.dart';
import '../screens/brands_screen.dart';
import '../screens/cart_page.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../customer/customer_model.dart';
import '../providers/cart_provider.dart';

class MainBottomBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final int cartItemCount;

  const MainBottomBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.cartItemCount = 0,
  }) : super(key: key);

  void _handleTap(BuildContext context, int index) {
    final customer = context.read<CustomerModel>();
    switch (index) {
      case 0:
      case 1:
        onItemSelected(index);
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BrandsScreen()),
        );
        break;

      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CartPage()),
        );
        break;

      case 4:
        if (customer.isLoggedIn) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AccountPage()),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerLoginRegister()),
          );
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = context.watch<CartProvider>();

    final items = [
      {
        "label": "Home",
        "outline": "assets/icons/HomeOutline.svg",
        "filled": "assets/icons/HomeBold.svg",
      },
      {
        "label": "Category",
        "outline": "assets/icons/CategoryOutline.svg",
        "filled": "assets/icons/CategoryBold.svg",
      },
      {
        "label": "Brand",
        "outline": "assets/icons/TicketStarOutline.svg",
        "filled": "assets/icons/TicketStarBold.svg",
      },
      {
        "label": "Cart",
        "outline": "assets/icons/BuyOutline.svg",
        "filled": "assets/icons/BuyBold.svg",
      },
      {
        "label": "Profile",
        "outline": "assets/icons/ProfileOutline.svg",
        "filled": "assets/icons/ProfileBold.svg",
      },
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 75, // ✅ clean fixed height
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset: const Offset(0, -8), // 👈 move shadow upwards
              color: Colors.black.withOpacity(0.08),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = selectedIndex == index;

            return Expanded(
              child: InkWell(
                onTap: () => _handleTap(context, index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: isSelected
                              ? const BoxDecoration(
                            color: Color(0xFFEA0180),
                            shape: BoxShape.circle,
                          )
                              : null,
                          child: AppIcon(
                            isActive: isSelected,
                            outlinePath: item["outline"] as String,
                            filledPath: item["filled"] as String,
                            size: 20,
                            color:
                            isSelected ? Colors.white : Colors.grey,
                          ),
                        ),

                        /// 🔥 CART BADGE
                        if (index == 3 && cartProvider.totalQuantity > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Container(
                                key: ValueKey(cartProvider.totalQuantity),
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEA0180),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Center(
                                  child: Text(
                                    cartProvider.totalQuantity.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item["label"] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFFEA0180)
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}