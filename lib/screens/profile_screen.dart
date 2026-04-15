import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/inner_page_app_bar.dart';
import '../customer/customer_orders.dart';
import '../widgets/main_bottom_bar.dart';
import 'wishlist_screen.dart';
import '../customer/customer_model.dart';
import '../customer/customer_addresses.dart';
import '../customer/customer_buy_again.dart';
import '../customer/customer_coupons.dart';
import 'package:provider/provider.dart';
import '../widgets/app_icon.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {

  int selectedIndex = 4;

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
        break;
      case 1:
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/brand');
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/cart');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  Widget buildMenuItem(Widget icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: icon,
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  Widget buildDivider() {
    return const Divider(
      thickness: 8,
      color: Color(0xffF2F2F2),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer');

    Navigator.pop(context);

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    final customerModel = context.watch<CustomerModel>();
    final customer = customerModel.customer;

    final userName = customer?['firstName'] ?? "User";

    /// 🔥 Loyalty Data
    final points = context.watch<CustomerModel>().loyaltyPoints;
    final tier = context.watch<CustomerModel>().vipTier;

    return Scaffold(
      backgroundColor: Colors.white,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        /// BACK ICON
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const SizedBox(
            width: 22,
            height: 22,
            child: AppIcon(
              isActive: false,
              outlinePath: 'assets/icons/ArrowLeft.svg',
              filledPath: 'assets/icons/ArrowLeft.svg',
            ),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),

      body: ListView(
        children: [

          /// 🔥 HEADER WITH LOYALTY
          Container(
            height: 140,
            width: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/pink-background.png"),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              color: Colors.black.withOpacity(0.35),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Hey",
                    style: TextStyle(color: Colors.white, fontSize: 20),
                  ),
                  Text(
                    userName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],
              ),
            ),
          ),

          /// 🎁 REWARDS CARD
          // Container(
          //   margin: const EdgeInsets.all(16),
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     gradient: const LinearGradient(
          //       colors: [Color(0xFFEA0180), Color(0xFFFF8ACD)],
          //     ),
          //     borderRadius: BorderRadius.circular(12),
          //   ),
          //   child: Row(
          //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
          //     children: [
          //       const Text(
          //         "My Loyalty Rewards",
          //         style: TextStyle(color: Colors.white, fontSize: 16),
          //       ),
          //       Text(
          //         "$points pts",
          //         style: const TextStyle(
          //           color: Colors.white,
          //           fontSize: 20,
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          buildDivider(),

          /// MENU ITEMS
          buildMenuItem(
            AppIcon(
              isActive: false,
              outlinePath: 'assets/icons/orderOutline.svg',
              filledPath: 'assets/icons/orderOutline.svg',
              size: 22,
            ),
            "My Orders",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerOrders(),
                ),
              );
            },
          ),

          buildMenuItem(
            AppIcon(
              isActive: false,
              outlinePath: 'assets/icons/HeartOutline.svg',
              filledPath: 'assets/icons/HeartOutline.svg',
              size: 22,
            ),
            "My Wishlist",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WishlistScreen(),
                ),
              );
            },
          ),

          buildMenuItem(
            AppIcon(
              isActive: false,
              outlinePath: 'assets/icons/HomeOutline.svg',
              filledPath: 'assets/icons/HomeOutline.svg',
              size: 22,
            ),
            "My Address",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CustomerAddresses(),
                ),
              );
            },
          ),

          buildMenuItem(
            AppIcon(
              isActive: false,
              outlinePath: 'assets/icons/Arrow_Right_Square.svg',
              filledPath: 'assets/icons/Arrow_Right_Square.svg',
              size: 22,
            ),
            "Buy Again",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BuyAgainPage(),
                ),
              );
            },
          ),

          buildMenuItem(
            AppIcon(
              isActive: false,
              outlinePath: 'assets/icons/TicketStarOutline.svg',
              filledPath: 'assets/icons/TicketStarOutline.svg',
              size: 22,
            ),
            "My Coupons",
                () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CouponsPage(),
                ),
              );
            },
          ),


          buildDivider(),

          /// LOGOUT
          ListTile(
            leading: ColorFiltered(
              colorFilter: const ColorFilter.mode( Color(0xFFEA0180),
                BlendMode.srcIn, ),
              child: const SizedBox(
                width: 22,
                height: 22,
                child:
                AppIcon(
                  isActive: false,
                  outlinePath: 'assets/icons/LogoutOutline.svg',
                  filledPath: 'assets/icons/LogoutOutline.svg', ),
              ),
            ),
            title:
            const Text(
              "Logout",
              style: TextStyle(
                  color: Color(0xFFEA0180),
                  fontSize: 16
              ),
            ),
            onTap: () async {
              final confirm = await showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Logout"),
                  content:
                  const Text("Are you sure you want to logout?"),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(context, true),
                      child: const Text(
                        "Logout",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await context.read<CustomerModel>().logout(context);
              }
            },
          ),
        ],
      ),

      bottomNavigationBar: MainBottomBar(
        selectedIndex: selectedIndex,
        onItemSelected: (index) {
          setState(() => selectedIndex = index);
          _handleNavigation(index);
        },
      ),
    );
  }
}