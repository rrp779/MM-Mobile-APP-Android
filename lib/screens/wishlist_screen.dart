import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/inner_page_app_bar.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  @override
  void initState() {
    super.initState();

    // 🔥 Load products when screen opens
    Future.microtask(() {
      context.read<WishlistProvider>().loadWishlist();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wishlistProvider = context.watch<WishlistProvider>();

    return Scaffold(
      appBar: const InnerPageAppBar(title: "Wishlist"),
      backgroundColor: Colors.white,
      body: wishlistProvider.wishlistProducts.isEmpty
          ? const Center(
        child: Text(
          "Your wishlist is empty",
          style: TextStyle(fontSize: 16),
        ),
      )
          : GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: wishlistProvider.wishlistProducts.length,
        gridDelegate:
        const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.55,
        ),
        itemBuilder: (_, index) {
          return ProductCard(
            product: wishlistProvider.wishlistProducts[index],
          );
        },
      ),
    );
  }
}