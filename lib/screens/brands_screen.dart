import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../widgets/inner_page_app_bar.dart';
import '../widgets/main_bottom_bar.dart';
import '../models/collection.dart';
import '../queries/brands_query.dart';
import '../config/shopify_client.dart';
import '../screens/collection_products_screen.dart';

class BrandsScreen extends StatefulWidget {
  const BrandsScreen({super.key});

  @override
  State<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends State<BrandsScreen> {
  int selectedIndex = 2;

  final ItemScrollController _itemScrollController =
  ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
  ItemPositionsListener.create();

  final TextEditingController _searchController =
  TextEditingController();
  final ValueNotifier<String> _searchNotifier =
  ValueNotifier('');

  /// ✅ ACTIVE LETTER (no rebuild of whole page)
  final ValueNotifier<int> _activeLetterIndex =
  ValueNotifier(0);

  Timer? _debounce;

  List<CollectionModel> _brands = [];
  bool _isLoading = true;
  String? _error;

  Future<void> _fetchBrands() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final client = getShopifyClient();
      bool hasNext = true;
      String? cursor;
      List<CollectionModel> fetchedBrands = [];

      while (hasNext) {
        final result = await client.query(
          QueryOptions(
            document: gql(collectionsQuery),
            variables: {'cursor': cursor},
            fetchPolicy: FetchPolicy.networkOnly,
          ),
        );

        if (result.hasException) {
          throw result.exception!;
        }

        final collections = result.data?['collections'];
        if (collections == null) break;

        final edges = collections['edges'] as List? ?? [];
        final pageBrands = edges
            .map((e) => CollectionModel.fromJson(e['node']))
            .where((c) => (c.collectiontype ?? '').toLowerCase().trim() == 'brand')
            .toList();

        fetchedBrands.addAll(pageBrands);

        hasNext = collections['pageInfo']?['hasNextPage'] ?? false;
        cursor = collections['pageInfo']?['endCursor'];
      }

      fetchedBrands.sort((a, b) => a.title.compareTo(b.title));

      if (mounted) {
        setState(() {
          _brands = fetchedBrands;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchBrands();

    _itemPositionsListener.itemPositions
        .addListener(() {
      final positions =
          _itemPositionsListener.itemPositions.value;

      if (positions.isEmpty) return;

      final visible = positions
          .where((pos) => pos.itemTrailingEdge > 0);

      if (visible.isEmpty) return;

      final firstVisible = visible.reduce(
            (min, pos) =>
        pos.itemLeadingEdge <
            min.itemLeadingEdge
            ? pos
            : min,
      );

      if (_activeLetterIndex.value !=
          firstVisible.index) {
        _activeLetterIndex.value =
            firstVisible.index;
      }
    });
  }

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(
            context, '/home');
        break;
      case 1:
        Navigator.pushReplacementNamed(
            context, '/category');
        break;
      case 3:
        Navigator.pushReplacementNamed(
            context, '/cart');
        break;
      case 4:
        Navigator.pushReplacementNamed(
            context, '/profile');
        break;
    }
  }

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false)
      _debounce!.cancel();

    _debounce =
        Timer(const Duration(milliseconds: 300),
                () {
              _searchNotifier.value =
                  value.toLowerCase();

              if (_itemScrollController
                  .isAttached) {
                _itemScrollController.scrollTo(
                  index: 0,
                  duration:
                  const Duration(milliseconds: 300),
                );
              }
            });
  }

  Widget _buildFallback(String title) {
    return Center(
      child: Text(
        title.isNotEmpty
            ? title[0].toUpperCase()
            : '',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBrandTile(CollectionModel brand) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollectionProductsScreen(
              collectionId: brand.handle,
              collectionTitle: brand.title,
              isBrand: true,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEFEFEF)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFEFEFEF)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (brand.image != null && brand.image!.isNotEmpty)
                    ? CachedNetworkImage(
                  imageUrl: brand.image!,
                  fit: BoxFit.contain,
                  memCacheWidth: 100, // 🔥 small image optimization
                  placeholder: (_, __) =>
                      Container(color: Colors.grey[200]),
                  errorWidget: (_, __, ___) =>
                      _buildFallback(brand.title),
                )
                    : _buildFallback(brand.title),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                brand.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchNotifier.dispose();
    _activeLetterIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget buildBody() {
      if (_isLoading) {
        return const Center(
          child: CircularProgressIndicator(
            color: Color(0xFFEA0180),
          ),
        );
      }

      if (_error != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _fetchBrands,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA0180),
                ),
                child: const Text("Retry", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }

      if (_brands.isEmpty) {
        return const Center(
          child: Text("No brands found"),
        );
      }

      return Column(
        children: [
          /// 🔍 SEARCH
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Search Brands...",
                  hintStyle: const TextStyle(fontSize: 14),
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                      setState(() {});
                    },
                  )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          /// 🔥 LIST
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _searchNotifier,
              builder: (context, searchQuery, _) {
                final filtered = _brands
                    .where((b) => b.title.toLowerCase().contains(searchQuery))
                    .toList();

                Map<String, List<CollectionModel>> grouped = {};
                for (var b in filtered) {
                  final l = b.title[0].toUpperCase();
                  grouped.putIfAbsent(l, () => []);
                  grouped[l]!.add(b);
                }

                final letters = grouped.keys.toList()..sort();

                return Stack(
                  children: [
                    ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      itemCount: letters.length,
                      itemBuilder: (context, index) {
                        final letter = letters[index];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: Text(
                                letter,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.only(left: 10, right: 45),
                              child: GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: grouped[letter]!.length > 20
                                    ? 20
                                    : grouped[letter]!.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 12,
                                  crossAxisSpacing: 12,
                                  childAspectRatio: 3,
                                ),
                                itemBuilder: (_, i) =>
                                    _buildBrandTile(grouped[letter]![i]),
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        );
                      },
                    ),

                    /// 🔥 SIDEBAR
                    Positioned(
                      right: 10,
                      top: 20,
                      bottom: 20,
                      child: ValueListenableBuilder<int>(
                        valueListenable: _activeLetterIndex,
                        builder: (context, active, _) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: letters.asMap().entries.map((entry) {
                              return GestureDetector(
                                onTap: () {
                                  if (_itemScrollController.isAttached) {
                                    _itemScrollController.scrollTo(
                                      index: entry.key,
                                      duration:
                                          const Duration(milliseconds: 300),
                                    );
                                    _activeLetterIndex.value = entry.key;
                                  }
                                },
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: active == entry.key
                                          ? const Color(0xFFEA0180)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      entry.value,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: active == entry.key
                                            ? Colors.white
                                            : const Color(0xFFEA0180),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const InnerPageAppBar(title: "Brands"),
      body: buildBody(),
      bottomNavigationBar: MainBottomBar(
        selectedIndex: selectedIndex,
        onItemSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
          _handleNavigation(index);
        },
      ),
    );
  }
}