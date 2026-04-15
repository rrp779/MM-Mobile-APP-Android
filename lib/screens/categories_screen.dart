// 🔥 ULTRA-OPTIMIZED CategoriesScreen (FAST + SMOOTH)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../models/collection.dart';
import '../queries/categories_query.dart';
import '../widgets/category_section.dart';
import '../widgets/main_bottom_bar.dart';
import '../widgets/inner_page_app_bar.dart';
import '../widgets/categoryscreen_skeleton.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with AutomaticKeepAliveClientMixin {
  int selectedIndex = 1;

  /// 🔥 Cached + Preprocessed Data
  List<CollectionModel>? _cachedCategories;
  Map<String, List<CollectionModel>> _groupedCategories = {};

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchNotifier = ValueNotifier('');

  Timer? _debounce;

  @override
  bool get wantKeepAlive => true;

  void _handleNavigation(int index) {
    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/home');
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

  /* =========================================================
      🔍 SEARCH (DEBOUNCED)
  ========================================================== */

  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 250), () {
      _searchNotifier.value = value.toLowerCase();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const InnerPageAppBar(title: "Category"),
      body: _buildBody(),
      bottomNavigationBar: MainBottomBar(
        selectedIndex: selectedIndex,
        onItemSelected: (index) {
          setState(() => selectedIndex = index);
          _handleNavigation(index);
        },
      ),
    );
  }

  /* =========================================================
      🚀 BODY (OPTIMIZED GRAPHQL)
  ========================================================== */

  Widget _buildBody() {
    return Query(
      options: QueryOptions(
        document: gql(collectionsQuery),

        /// 🔥 CACHE FIRST = INSTANT LOAD
        fetchPolicy: FetchPolicy.cacheFirst,

        /// 🔥 PREVENT RE-FETCH
        cacheRereadPolicy: CacheRereadPolicy.ignoreAll,
      ),
      builder: (result, {refetch, fetchMore}) {
        if (result.isLoading && _cachedCategories == null) {
          return const CategorySkeleton();
        }

        if (result.hasException) {
          return const Center(child: Text("Something went wrong"));
        }

        /// 🔥 PROCESS ONLY ONCE (VERY IMPORTANT)
        if (_cachedCategories == null) {
          final edges = result.data!['collections']['edges'] as List;

          _cachedCategories = edges
              .map((e) => CollectionModel.fromJson(e['node']))
              .where((c) => c.collectiontype?.toLowerCase() == 'category')
              .toList();

          _groupCategories(_cachedCategories!);
        }

        return Column(
          children: [
            _searchBar(),

            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: _searchNotifier,
                builder: (context, searchQuery, _) {
                  final grouped = _filterGrouped(searchQuery);

                  if (grouped.isEmpty) {
                    return const Center(
                      child: Text("No categories found"),
                    );
                  }

                  final customOrder = [
                    "Makeup",
                    "Skin Care",
                    "Hair Care",
                    "Tools",
                    "Other"
                  ];

                  final keys = grouped.keys.toList();

                  keys.sort((a, b) {
                    int indexA = customOrder.indexOf(a);
                    int indexB = customOrder.indexOf(b);

                    if (indexA == -1) indexA = 999;
                    if (indexB == -1) indexB = 999;

                    return indexA.compareTo(indexB);
                  });
                  /// 🚀 SLIVER + LAZY BUILD
                  return CustomScrollView(
                    cacheExtent: 800,
                    slivers: keys.map((key) {
                      return SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: CategorySection(
                            title: key.toUpperCase(),
                            categories: grouped[key]!,
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
    );
  }

  /* =========================================================
      🔥 PRE-GROUPING (RUNS ONCE)
  ========================================================== */

  void _groupCategories(List<CollectionModel> categories) {
    final Map<String, List<CollectionModel>> grouped = {};

    for (var category in categories) {
      final parent =
      (category.parentCategory?.trim().isNotEmpty ?? false)
          ? category.parentCategory!
          : "Other";

      grouped.putIfAbsent(parent, () => []);
      grouped[parent]!.add(category);
    }

    _groupedCategories = grouped;
  }

  /* =========================================================
      🔍 FILTER (FAST - NO RE-GROUPING)
  ========================================================== */

  Map<String, List<CollectionModel>> _filterGrouped(String query) {
    if (query.isEmpty) return _groupedCategories;

    final Map<String, List<CollectionModel>> filtered = {};

    _groupedCategories.forEach((key, list) {
      final matches = list
          .where((c) => c.title.toLowerCase().contains(query))
          .toList();

      if (matches.isNotEmpty) {
        filtered[key] = matches;
      }
    });

    return filtered;
  }

  /* =========================================================
      🔍 SEARCH BAR (LIGHTWEIGHT)
  ========================================================== */

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Search category...",
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: const Color(0xFFF5F5F5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
