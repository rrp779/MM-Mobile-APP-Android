import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import '../providers/wishlist_provider.dart';
import '../models/product.dart';
import '../graphql/product_detail_query.dart';
import '../widgets/product_card.dart';
import '../widgets/inner_page_app_bar.dart';
import '../widgets/product_bottom_bar.dart';
import '../widgets/product_horizontal_slider.dart';
import '../widgets/product_detail_skeleton.dart';
import '../services/review_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProductDetailScreen extends StatefulWidget {

  final String? productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() =>
      _ProductDetailScreenState(

      );
}

class _ProductDetailScreenState

    extends State<ProductDetailScreen> {
  int selectedVariantIndex = 0;
  int currentImageIndex = 0;
  int quantity = 1;
  late PageController _pageController;
  final ScrollController _thumbScrollController =
  ScrollController();
  late ScrollController _indicatorScrollController;
  Timer? _autoPlayTimer;



  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _indicatorScrollController = ScrollController();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    _thumbScrollController.dispose();
    _indicatorScrollController.dispose();
    super.dispose();
  }


  String _getPreviewText(String html, {int wordLimit = 40}) {
    final plainText = html
        .replaceAll(RegExp(r'<[^>]*>'), '') // remove html tags
        .replaceAll('&nbsp;', ' ')
        .trim();

    final words = plainText.split(RegExp(r'\s+'));

    if (words.length <= wordLimit) {
      return plainText;
    }



    return "${words.take(wordLimit).join(' ')}...";
  }
  void _showFullDescription(String html) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
            top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, controller) {
            return Padding(
              padding:
              const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 5,
                    decoration:
                    BoxDecoration(
                      color:
                      Colors.grey.shade300,
                      borderRadius:
                      BorderRadius
                          .circular(10),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    "Product Details",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                      FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Expanded(
                    child:
                    SingleChildScrollView(
                      controller: controller,
                      child: Html(
                        data: html,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _scrollIndicatorToCenter(int itemCount) {
    if (!_indicatorScrollController.hasClients) return;

    const double dotFullWidth = 16; // size + margin
    const double visibleWidth = 80; // indicator strip width

    double targetOffset =
        (currentImageIndex * dotFullWidth) - (visibleWidth / 2) + (dotFullWidth / 2);

    targetOffset = targetOffset.clamp(
      0,
      _indicatorScrollController.position.maxScrollExtent,
    );

    _indicatorScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }


  void _startAutoplay(List<String> images) {
    if (_autoPlayTimer != null || images.length <= 1) return;

    _autoPlayTimer = Timer.periodic(
      const Duration(seconds: 3),
          (_) {
        if (!mounted) return;

        int next =
            (currentImageIndex + 1) % images.length;

        _pageController.animateToPage(
          next,
          duration:
          const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      },
    );
  }
  String getNumericProductId(String gid) {
    return gid.split('/').last;
  }

  Widget buildReviews(String productGid) {

    final productId = getNumericProductId(productGid);

    return FutureBuilder(
      future: ReviewService.fetchProductReviews(productId),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text("No reviews yet"),
          );
        }

        final reviews = snapshot.data as List;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              const SizedBox(height: 20),

              const Center(
                child: Text(
                  "Customer Reviews",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                itemBuilder: (context, index) {

                  final review = reviews[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// Stars
                        Row(
                          children: List.generate(
                            review["rating"],
                                (i) => const Icon(
                              Icons.star,
                              color: Color(0xFFEA0180),
                              size: 18,
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        /// Reviewer Name
                        Text(
                          review["reviewer"]["name"],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        /// Review Comment
                        Text(
                          review["body"] ?? "",
                          style: const TextStyle(
                            fontSize: 14,
                          ),
                        ),

                        const Divider(height: 30),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {

    Widget buildPremiumIndicator(List<String> images) {
      if (images.length <= 1) return const SizedBox();

      return Center(
        child: SizedBox(
          width: 80,
          height: 14,
          child: ListView.builder(
            controller: _indicatorScrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: images.length,
            itemBuilder: (context, index) {
              final difference = (currentImageIndex - index).abs();

              double size;
              Color color;

              if (difference == 0) {
                size = 8; // active
                color = const Color(0xFFE91E63);
              } else if (difference == 1) {
                size = 6; // adjacent
                color = Colors.grey.shade600;
              } else {
                size = 4; // others
                color = Colors.grey.shade400;
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              );
            },
          ),
        ),
      );
    }

    return Query(
      options: QueryOptions(
        document: gql(productDetailQuery),
        variables: {"id": widget.productId},
      ),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading) {
          return const Scaffold(
            body: ProductDetailSkeleton(),
          );
        }
        if (result.hasException) {
          return Scaffold(
            body: Center(
              child: Text(result.exception.toString()),
            ),
          );
        }

        final productJson = result.data!['product'];
        final product =
        Product.fromJson(productJson);

        final selectedVariant =
        product.variants[selectedVariantIndex];

        /// 🔥 Variant Image Priority Logic
        List<String> images = [];

        if (selectedVariant.image != null &&
            selectedVariant.image!.isNotEmpty) {
          images = [
            selectedVariant.image!,
            ...product.images.where(
                  (img) =>
              img != selectedVariant.image,
            ),
          ];
        } else {
          images = product.images.isNotEmpty
              ? product.images
              : [product.image];
        }

        for (var img in images.take(3)) {
          precacheImage(
            CachedNetworkImageProvider(img),
            context,
          );
        }

        _startAutoplay(images);

        final hasDiscount =
            selectedVariant.compareAt != null &&
                selectedVariant.compareAt! >
                    selectedVariant.price;

        final discountPercent = hasDiscount
            ? (((selectedVariant.compareAt! -
            selectedVariant.price) /
            selectedVariant.compareAt!) *
            100)
            .round()
            : 0;

        return Scaffold(
          appBar: InnerPageAppBar(
            title: "",

          ),
          backgroundColor: Colors.white,

          body: SingleChildScrollView(
            padding:
            const EdgeInsets.only(bottom: 110),
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [

                /// MAIN IMAGE SLIDER
                SizedBox(
                  height: 400,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() {
                        currentImageIndex = index;
                      });

                      _scrollIndicatorToCenter(images.length);

                      if (images.length > 5) {
                        _thumbScrollController
                            .animateTo(
                          index * 70,
                          duration:
                          const Duration(
                              milliseconds:
                              300),
                          curve:
                          Curves.easeInOut,
                        );
                      }
                    },
                    itemBuilder: (context, index) {
                      return CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        memCacheWidth: (MediaQuery.of(context).size.width * 2).toInt(),
                        placeholder: (_, __) => Container(
                          color: Colors.grey.shade200,
                        ),
                        errorWidget: (_, __, ___) =>
                        const Icon(Icons.broken_image),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 8),

                /// DOT INDICATOR
                buildPremiumIndicator(images),

                const SizedBox(height: 8),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// ───── BRAND + TITLE + PRICE ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          if (product.brandTitle != null &&
                              product.brandTitle!.isNotEmpty)
                            Text(
                              product.brandTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF01040C),
                                decoration: TextDecoration.underline,
                              ),
                            ),

                          const SizedBox(height: 5),

                          /// TITLE
                          Text(
                            product.title,
                            style: const TextStyle(
                              fontSize: 16,
                            ),
                          ),

                          const SizedBox(height: 5),

                          /// PRICE
                          Row(
                            children: [
                              Text(
                                "₹${selectedVariant.price.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF000000),
                                ),
                              ),
                              if (hasDiscount) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "₹${selectedVariant.compareAt!.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "$discountPercent% OFF",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 5),
                    const Divider(thickness: 0.5, color: Color(0xFFE5E5E5)),

                    /// ───── VARIANTS ─────
                    if (product.variantCount > 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                                children: [
                                  const TextSpan(text: "Select Variant : "),
                                  TextSpan(
                                    text: product.variants[selectedVariantIndex].title,
                                    style: const TextStyle(
                                      color: Color(0xFFEA0180),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            SizedBox(
                              height: 60,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: product.variantCount,
                                itemBuilder: (context, index) {

                                  final variant = product.variants[index];
                                  final isSelected = selectedVariantIndex == index;
                                  final hasImage =
                                      variant.image != null && variant.image!.isNotEmpty;

                                  final isOutOfStock =
                                  !(variant.availableForSale ?? true);

                                  return GestureDetector(
                                    onTap: isOutOfStock
                                        ? null
                                        : () {
                                      setState(() {
                                        selectedVariantIndex = index;
                                        currentImageIndex = 0;
                                      });

                                      _pageController.animateToPage(
                                        0,
                                        duration: const Duration(milliseconds: 400),
                                        curve: Curves.easeInOut,
                                      );
                                    },
                                    child: Opacity(
                                      opacity: isOutOfStock ? 0.5 : 1,
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: 60,
                                            height: 60,
                                            margin: const EdgeInsets.only(right: 5),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFFEA0180)
                                                    : Colors.grey.shade300,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: hasImage
                                                  ? CachedNetworkImage(
                                                imageUrl: variant.image!,
                                                fit: BoxFit.contain,
                                                memCacheWidth: 300,
                                                placeholder: (_, __) => Container(
                                                  color: Colors.grey.shade200,
                                                ),
                                                errorWidget: (_, __, ___) =>
                                                const Icon(Icons.broken_image),
                                              )
                                                  : Center(
                                                child: Text(
                                                  variant.title,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: isSelected
                                                        ? const Color(0xFFEA0180)
                                                        : Colors.black87,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          // ❌ Overlay when out of stock
                                          if (isOutOfStock)
                                            Positioned.fill(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withOpacity(0.6),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.close,
                                                    color: Colors.red,
                                                    size: 28,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 5),
                    const Divider(thickness: 0.5, color: Color(0xFFE5E5E5)),

                    /// ───── SELLER ─────
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.black,
                          ),
                          children: [
                            TextSpan(text: "Sold By : ",
                              style: TextStyle(
                                 color: Color(0xFF727272),
                              ),
                            ),
                            TextSpan(
                              text: "Makeup Mystery India",
                              style: TextStyle(

                              ),
                            ),
                          ],
                        ),
                      ),
                    ),


                    const SizedBox(height: 10),
                    const Divider(thickness: 10, color: Color(0xFFf3f3f3)),
                    /// ───── TRUST SECTION ─────
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFFFFFF),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          /// Authorised Dealer
                          Expanded(
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.verified_user_outlined,
                                  size: 20,
                                  color: const Color(0xFFEA0180),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Authorised Dealer",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,

                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// Fast Delivery
                          Expanded(
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.local_shipping_outlined,
                                  size: 20,
                                  color: const Color(0xFFEA0180),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Fast Delivery",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,

                                  ),
                                ),
                              ],
                            ),
                          ),

                          /// Orders Shipped
                          Expanded(
                            child: Column(
                              children: const [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 20,
                                  color: const Color(0xFFEA0180),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "25k+ Orders Shipped",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,

                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(thickness: 10, color: Color(0xFFf3f3f3)),
                    const SizedBox(height: 10),

                    /// ───── DESCRIPTION ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          const Text(
                            "Product Details :",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                if (product.descriptionHtml.isNotEmpty) ...[
                                  Text(
                                    _getPreviewText(product.descriptionHtml, wordLimit: 35),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.6,
                                      color: Colors.black87,
                                    ),
                                  ),

                                  const SizedBox(height: 10),

                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: GestureDetector(
                                      onTap: () {
                                        _showFullDescription(product.descriptionHtml);
                                      },
                                      child: const Text(
                                        "Read More →",
                                        style: TextStyle(
                                          color: Color(0xFFEA0180),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ] else
                                  const Text(
                                    "No description available.",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(thickness: 10, color: Color(0xFFf3f3f3)),
                    const SizedBox(height: 10),
                    /// ───── SLIDERS (FULL WIDTH) ─────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: ProductHorizontalSlider(
                        productId: product.id,
                        title: "More Like This",
                      ),
                    ),
                    const SizedBox(height: 30),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      child: ProductHorizontalSlider(
                      productId: product.id,
                      title: "Related Products",
                      useCollectionLogic: true,
                    ),
                    ),

                    const SizedBox(height: 30),

                   // buildReviews(product.id),

                  ],
                )
              ],
            ),
          ),

          bottomNavigationBar: ProductBottomBar(
            product: product,
            selectedVariantId: selectedVariant.id,
            quantity: quantity,
          ),
        );
      },
    );
  }


}
