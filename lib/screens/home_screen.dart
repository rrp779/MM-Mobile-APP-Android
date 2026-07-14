import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../models/home_section.dart';
import '../widgets/top_bar.dart';
import '../widgets/main_bottom_bar.dart';
import '../screens/collection_products_screen.dart';
import '../widgets/product_card.dart';
import '../widgets/product_card_skeleton.dart';
import 'product_detail_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/product.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  PageController _sliderController = PageController();
  int _currentPage = 0;

  int selectedIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _sliderController = PageController(viewportFraction: 1.0);

    Future.microtask(() async {
      final provider = context.read<HomeProvider>();

      if (provider.sections.isEmpty) {
        /// 🔥 preload products (BIG speed boost)
        // FIXED: Removed redundant product fetch, fetchSections handles it
        await provider.fetchSections();
      }
    });
  }

  Widget _cachedImage(
      String url, {
        double? height,
        double? width,
        BoxFit fit = BoxFit.cover,
      }) {
    if (url.isEmpty) {
      return Container(
        height: height,
        width: width,
        color: Colors.grey[200],
      );
    }

    return CachedNetworkImage(
      imageUrl: url,
      height: height,
      width: width,
      fit: fit,
      memCacheWidth: 800,
      placeholder: (_, __) => Container(
        height: height,
        width: width,
        color: Colors.grey[200],
      ),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
    );
  }

  @override
  void dispose() {
    _sliderController.dispose();
    super.dispose();
  }
  void _startAutoSlide(int total) {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted || !_sliderController.hasClients) return;

      _currentPage++;

      if (_currentPage >= total) {
        _currentPage = 0;
      }

      _sliderController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );

      _startAutoSlide(total); // 🔁 loop
    });
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 1:
        Navigator.pushNamed(context, '/category');
        break;
      case 2:
        Navigator.pushNamed(context, '/brand');
        break;
      case 3:
        Navigator.pushNamed(context, '/cart');
        break;
      case 4:
        Navigator.pushNamed(context, '/profile');
        break;

    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isLoading =
    context.select<HomeProvider, bool>((p) => p.isLoading);

    final sections =
    context.select<HomeProvider, List<HomeSection>>((p) => p.sections);

    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: MainBottomBar(
        selectedIndex: selectedIndex,
        onItemSelected: (index) {
          setState(() => selectedIndex = index);
          _handleNavigation(index);
        },
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final provider = context.read<HomeProvider>();
            // FIXED: Added forceRefresh: true
            await provider.fetchSections(forceRefresh: true);
          },
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              const SliverToBoxAdapter(child: HomeTopBar()),
              ..._buildSections(sections),
              SliverToBoxAdapter(child: _buildFeatureStrip()),
              const SliverToBoxAdapter(
                child: SizedBox(height: 80),
              ),
            ],
          ) 
        ),
      ),
    );
  }


  Widget _buildFeatureStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        color: const Color(0xFFFFFFFF), // light pink bg like screenshot
         padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [

            _featureItem(
              iconPath: "assets/icons/authentic_icon.png",
              title: "100% Authentic",
            ),

            _featureItem(
              iconPath: "assets/icons/fast_delivery_icon.png",
              title: "Fast Delivery",
            ),

            _featureItem(
              iconPath: "assets/icons/brands_icon.png",
              title: "150+ Brands",
            ),

          ],
        ),
      ),
    );
  }
  /* ================= SECTION WRAPPER ================= */

  Widget _sectionWrapper(HomeSection section, Widget child) {
    final settings = section.settings;

    Decoration? decoration;

    if (settings.backgroundImage.isNotEmpty) {
      decoration = BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(settings.backgroundImage),
          fit: BoxFit.cover,
        ),
        borderRadius:
        BorderRadius.circular(settings.borderRadius.toDouble()),
      );
    } else if (settings.gradientStart.isNotEmpty &&
        settings.gradientEnd.isNotEmpty) {
      decoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _hexToColor(settings.gradientStart),
            _hexToColor(settings.gradientEnd),
          ],
        ),
        borderRadius:
        BorderRadius.circular(settings.borderRadius.toDouble()),
      );
    } else {
      decoration = BoxDecoration(
        color: _hexToColor(settings.backgroundColor),
        borderRadius:
        BorderRadius.circular(settings.borderRadius.toDouble()),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10), // 🔥 spacing between sections
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: 10,
          bottom: 10,
        ),
        decoration: decoration,
        child: child,
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  /* ================= SECTION BUILDER ================= */

  List<Widget> _buildSections(List<HomeSection> sections) {
    final visibleSections = sections.where((s) => s.visible).toList();

    if (visibleSections.isEmpty) {
      return [
        const SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No data available"),
                ],
              ),
            ),
          ),
        )
      ];
    }

    return visibleSections.map((section) {
      Widget content;

      switch (section.type) {
        case "hero":
          content = _buildHero(section);
          break;
        case "collection_grid":
          content = _buildCollectionGrid(section);
          break;
        case "collection_slider":
          content = section.settings.sliderStyle == "full"
              ? _buildFullWidthSlider(section)
              : _buildCollectionSlider(section);
          break;
        case "banner":
          content = _buildBanner(section);
          break;
        case "best_selling":
        case "trending_products":
          content = _buildProductSlider(section);
          break;
        case "two_column_grid":
          content = _buildTwoColumnGrid(section);
          break;
        case "banner_slider":
          content = _buildBannerStack(section);
          break;
        default:
          content = const SizedBox.shrink();
      }

      return SliverToBoxAdapter(
        child: _sectionWrapper(section, content),
      );
    }).toList();
  }

  /* ================= HERO ================= */

  Widget _buildHero(HomeSection section) {
    final items = section.items.where((i) => i.visible).toList();

    return SizedBox(
      height: 240,
      child: PageView.builder(
        itemCount: items.length,
        itemBuilder: (_, i) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: _cachedImage(
                items[i].image ?? "",
                fit: BoxFit.cover,
              ),
            ),
          );
        },
      ),
    );
  }

  /* ================= COLLECTION ================= */

  Widget _collectionCard(SectionItem item, {double width = 100}) {
    final imageUrl =
        item.image ?? item.collectionImage ?? item.productImage ?? "";

    return GestureDetector(
      onTap: () {
        final handle = item.collectionHandle;
        final id = item.collectionId;

        if ((handle == null || handle.isEmpty) &&
            (id == null || id.isEmpty)) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollectionProductsScreen(
              collectionId: id ?? "",
              collectionHandle: handle,
              collectionTitle: item.title,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: width,
          child: _cachedImage(
            imageUrl,
            width: width,
            fit: BoxFit.cover, // 🔥 important change
          ),
        ),
      ),
    );
  }

  /* ================= GRID ================= */

  Widget _buildCollectionGrid(HomeSection section) {
    final items = section.items.where((i) => i.visible).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // 3 columns with spacing
        final itemWidth = (screenWidth - (13 * 4)) / 3;
        return SizedBox(
          height: itemWidth * 1.0, // 🔥 dynamic height (adjust if needed)
          child: ListView.builder(
            primary: false,
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            padding: const EdgeInsets.only(right: 13),
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.only(left: 13),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12), // 🔥 radius here
                  child: SizedBox(
                    width: itemWidth,
                    child: _collectionCard(
                      items[i],
                      width: itemWidth,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  /* ================= SMALL SLIDER ================= */

  Widget _buildCollectionSlider(HomeSection section) {
    final items = section.items.where((i) => i.visible).toList();

    return SizedBox(
      height: 140,
      child: LayoutBuilder(
        builder: (context, constraints) {

          final totalWidth = constraints.maxWidth;

          const spacing = 10.0;
          const sidePadding = 15.0;

          // 🔥 calculate exact width for 4 items
          final itemWidth =
              (totalWidth - (spacing * 3) - sidePadding) / 4;

          return ListView.builder(
            primary: false,
            scrollDirection: Axis.horizontal,
            cacheExtent: 500,
            padding: const EdgeInsets.only(left: 5),
            itemCount: items.length,
            itemBuilder: (_, i) {
              return Padding(
                padding: const EdgeInsets.only(right: spacing),
                child: SizedBox(
                  width: itemWidth, // ✅ perfectly 4 items fit
                  child: _collectionCard(
                    items[i],
                    width: double.infinity,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /* ================= FULL WIDTH SLIDER ================= */

  Widget _buildFullWidthSlider(HomeSection section) {
    final items = section.items.where((i) => i.visible).toList();
    if (items.isEmpty) return const SizedBox();

    final total = items.length;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentPage == 0) {
        _startAutoSlide(total);
      }
    });

    return Column(
      children: [
        if (section.title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 0),
            child: Text(
              section.title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _sliderController,
            onPageChanged: (index) {
              _currentPage = index;
            },
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final imageUrl =
                  item.image ??
                      item.collectionImage ??
                      item.productImage ??
                      "";

              return GestureDetector(
                onTap: () {
                  final handle = item.collectionHandle;
                  final id = item.collectionId;

                  if ((handle == null || handle.isEmpty) &&
                      (id == null || id.isEmpty)) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CollectionProductsScreen(
                        collectionId: handle ?? id!,
                        collectionHandle: handle,
                        collectionTitle: item.title,
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child:_cachedImage(
                      imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /* ================= TWO COLUMN GRID ================= */

  Widget _buildTwoColumnGrid(HomeSection section) {
    final items = section.items.where((i) => i.visible).toList();

    final isSlider = section.settings.layoutStyle == "slider";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// ✅ TITLE
        if (section.title.isNotEmpty)
          _sectionTitle(section.title),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),

          /// 🔥 SWITCH GRID / SLIDER
          child: isSlider

          /// ================= SLIDER =================
              ? SizedBox(
            height: 220,
            child: ListView.builder(
              primary: false,
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];

                final imageUrl =
                    item.image ??
                        item.productImage ??
                        item.collectionImage ??
                        item.thumbnail ??
                        "";

                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width / 2.2,
                    child: GestureDetector(
                      onTap: () {
                        /// PRODUCT
                        if (item.productId != null &&
                            item.productId!.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                productId: item.productId!,
                              ),
                            ),
                          );
                          return;
                        }

                        /// COLLECTION
                        final handle = item.collectionHandle;
                        final id = item.collectionId;

                        if ((handle != null && handle.isNotEmpty) ||
                            (id != null && id.isNotEmpty)) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CollectionProductsScreen(
                                collectionId: id ?? "",
                                collectionHandle: handle,
                                collectionTitle: item.title,
                              ),
                            ),
                          );
                        }
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _cachedImage(imageUrl, fit: BoxFit.cover,),
                      ),
                    ),
                  ),
                );
              },
            ),
          )

          /// ================= GRID =================
              : GridView.builder(
            primary: false,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.75,
            ),
            itemBuilder: (_, i) {
              final item = items[i];

              final imageUrl =
                  item.image ??
                      item.productImage ??
                      item.collectionImage ??
                      item.thumbnail ??
                      "";

              return GestureDetector(
                onTap: () {
                  /// PRODUCT
                  if (item.productId != null &&
                      item.productId!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          productId: item.productId!,
                        ),
                      ),
                    );
                    return;
                  }

                  /// COLLECTION
                  final handle = item.collectionHandle;
                  final id = item.collectionId;

                  if ((handle != null && handle.isNotEmpty) ||
                      (id != null && id.isNotEmpty)) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CollectionProductsScreen(
                          collectionId: id ?? "",
                          collectionHandle: handle,
                          collectionTitle: item.title,
                        ),
                      ),
                    );
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _cachedImage(imageUrl, fit: BoxFit.cover,),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /* ================= BANNER STACK ================= */

  Widget _buildBannerStack(HomeSection section) {
    final items = section.items.where((i) => i.visible).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        /// ✅ SECTION TITLE
        if (section.title.isNotEmpty)
          _sectionTitle(section.title),

        ...items.map((item) {
          final imageUrl =
              item.image ??
                  item.productImage ??
                  item.collectionImage ??
                  item.thumbnail ??
                  "";

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: GestureDetector(
              onTap: () {

                /// 🔥 PRODUCT CLICK
                if (item.productId != null && item.productId!.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(
                        productId: item.productId!,
                      ),
                    ),
                  );
                  return;
                }

                /// 🔥 COLLECTION CLICK
                final handle = item.collectionHandle;
                final id = item.collectionId;

                if ((handle != null && handle.isNotEmpty) ||
                    (id != null && id.isNotEmpty)) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CollectionProductsScreen(
                        collectionId: id ?? "",
                        collectionHandle: handle,
                        collectionTitle: item.title,
                      ),
                    ),
                  );
                }
              },

              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _cachedImage(
                  imageUrl,
                  width: double.infinity,
                  height: 280,
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  /* ================= BANNER ================= */

  Widget _buildBanner(HomeSection section) {
    final item = section.items.first;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // ✅ padding
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // ✅ border radius
        child: _cachedImage(
          item.image ?? "",
          height: 220,
          width: double.infinity,
        ),
      ),
    );
  }
  /* ================= PRODUCTS ================= */
  Widget _buildProductSlider(HomeSection section) {
    final provider = context.watch<HomeProvider>();
    final productsMap = provider.productsMap;
    final items = section.items.where((i) => i.visible).toList();
    return Column(
      children: [
        _sectionTitle(section.title),
        SizedBox(
          height: 340,
          child: ListView.builder(
            primary: false,
            scrollDirection: Axis.horizontal,
            cacheExtent: 600,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              final id = item.productId;
              final product = id != null ? productsMap[id] : null;

              Widget cardChild;
              if (product != null) {
                cardChild = RepaintBoundary(
                  child: ProductCard(product: product),
                );
              } else if (provider.isProductLoading(id)) {
                cardChild = const Center(child: CircularProgressIndicator());
              } else {
                cardChild = _buildProductFallbackCard(item);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: SizedBox(
                  width: 170,
                  child: cardChild,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductFallbackCard(SectionItem item) {
    final imageUrl = item.thumbnail ??
        item.image ??
        item.productImage ??
        item.collectionImage ??
        "";

    return GestureDetector(
      onTap: () {
        if (item.productId != null && item.productId!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductDetailScreen(
                productId: item.productId!,
              ),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _cachedImage(
              imageUrl,
              height: 200,
              width: 170,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _featureItem({
    required String iconPath,
    required String title,
  }) {
    return Column(
      children: [
        Container(
          width: 90,
          height:90,

          child: Center(
            child: Image.asset(
              iconPath,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFEA0180),
          ),
        ),
      ],
    );
  }
  /* ================= TITLE ================= */

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Center(
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
